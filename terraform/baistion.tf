# Bastion Host Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-bastion-sg"
  }
}

# Find Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Public Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "eks-terraform-key"

  associate_public_ip_address = true

  tags = {
    Name = "${var.cluster_name}-public-bastion"
  }
}

# Private Bastion Host Security Group
resource "aws_security_group" "private_bastion_sg" {
  name        = "${var.cluster_name}-private-bastion-sg"
  description = "Security group for private bastion host"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Allow SSH only from public bastion SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-private-bastion-sg"
  }
}

resource "aws_instance" "private_bastion" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.private_bastion_sg.id]
  key_name               = "eks-terraform-key"

  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update packages
    yum -y update

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/

    # Install aws-iam-authenticator
    curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator
    chmod +x ./aws-iam-authenticator
    mv ./aws-iam-authenticator /usr/local/bin

    # Upgrade AWS CLI to v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip awscliv2.zip
    ./aws/install
  EOF

  tags = {
    Name = "${var.cluster_name}-private-bastion"
  }
}
