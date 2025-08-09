# Local variable for Kubernetes version
locals {
  eks_version = var.kubernetes_version
}

# Data for EKS AMI release
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${local.eks_version}/amazon-linux-2/recommended/release_version"
}

data "aws_ami" "eks_worker_ami" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.eks_version}-v*"]
  }
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI owner ID
}

# ---------------- IAM Roles ----------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# ---------------- EKS Cluster ----------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.private_subnets[*].id
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = var.cluster_name
  }
}

# ---------------- Node Group ----------------
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.private_subnets[*].id

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"
  disk_size       = var.node_disk_size
  ami_type        = var.ami_type
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)

  dynamic "launch_template" {
    for_each = var.custom_ami_id != "" ? [1] : []
    content {
      name    = aws_launch_template.eks_nodes[0].name
      version = aws_launch_template.eks_nodes[0].latest_version
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}

resource "aws_launch_template" "eks_nodes" {
  count = var.custom_ami_id != "" ? 1 : 0

  name_prefix            = "${var.cluster_name}-node-template-"
  image_id               = var.custom_ami_id
  instance_type          = var.node_instance_types[0]
  vpc_security_group_ids = [aws_security_group.eks_nodes_sg.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.node_disk_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
/etc/eks/bootstrap.sh ${aws_eks_cluster.eks_cluster.name} ${var.bootstrap_arguments}
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-worker-node"
    }
  }

  tags = {
    Name = "${var.cluster_name}-launch-template"
  }
}

# ---------------- VPC Endpoint ----------------
resource "aws_vpc_endpoint" "eks_endpoint" {
  vpc_id              = aws_vpc.eks_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnets[*].id
  security_group_ids  = [aws_security_group.eks_cluster_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-eks-endpoint"
  }
}

# ---------------- Admin Access ----------------
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "admin_access" {
  count         = var.create_admin_access_entry ? 1 : 0
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Get EKS cluster authentication token
data "aws_eks_cluster_auth" "eks_auth" {
  name = aws_eks_cluster.eks_cluster.name
}

# Kubernetes provider - must run from a host that can reach the private EKS API
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}
