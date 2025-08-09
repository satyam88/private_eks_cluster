terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------- VPC ----------------
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Type                                        = "Private"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_eip" "nat_eips" {
  count      = length(var.private_subnet_cidrs)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.eks_igw]

  tags = {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat_gateways" {
  count         = length(var.private_subnet_cidrs)
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.eks_igw]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_associations" {
  count = length(aws_subnet.public_subnets)

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_tables" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateways[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-route-table-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_subnet_associations" {
  count = length(aws_subnet.private_subnets)

  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
}

# ---------------- Security Groups ----------------
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = aws_vpc.eks_vpc.id

  # Allow inbound HTTPS (API Server)
  ingress {
    description = "Allow API server access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ideally restrict this to trusted IPs or SGs
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group" "eks_nodes_sg" {
  name_prefix = "${var.cluster_name}-nodes-sg"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-nodes-sg"
  }
}
