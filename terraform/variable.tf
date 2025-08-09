# terraform/variables.tf

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "private-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (for NAT Gateways)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 4
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "custom_ami_id" {
  description = "Custom AMI ID for worker nodes (leave empty to use latest EKS optimized AMI)"
  type        = string
  default     = ""
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2_x86_64"
  validation {
    condition     = contains(["AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64", "CUSTOM"], var.ami_type)
    error_message = "AMI type must be one of: AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM."
  }
}

variable "bootstrap_arguments" {
  description = "Additional arguments to pass to the EKS bootstrap script"
  type        = string
  default     = ""
}

variable "bastion_key_pair" {
  description = "EC2 Key Pair name for bastion host"
  type        = string
  default     = ""
}

variable "create_admin_access_entry" {
  description = "Whether to create the EKS admin access entry"
  type        = bool
  default     = false
}

