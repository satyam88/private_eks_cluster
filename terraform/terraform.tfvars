# terraform/terraform.tfvars

aws_region         = "ap-south-1"
cluster_name       = "private-eks-cluster"
kubernetes_version = "1.31"


vpc_cidr = "10.0.0.0/16"

# Public subnets for NAT Gateways (in different AZs)
public_subnet_cidrs = [
  "10.0.1.0/24", # ap-south-1a
  "10.0.2.0/24"  # ap-south-1b
]

# Private subnets for EKS cluster and nodes (in different AZs)
private_subnet_cidrs = [
  "10.0.10.0/24", # ap-south-1a
  "10.0.20.0/24"  # ap-south-1b
]

# Node Group Configuration
node_instance_types     = ["t3.micro"]
node_group_desired_size = 1
node_group_max_size     = 4
node_group_min_size     = 1
node_disk_size          = 20