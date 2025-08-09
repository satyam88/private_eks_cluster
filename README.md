VPC Setup
==========
2 Public and 2 Private Subnets in ap-south-1a and ap-south-1b respectively
Internet Gateway for public subnet access
NAT Gateway for internet connectivity
Route tables associated with the respective subnets

EKS v1.33
===========
Provisions an EKS cluster with private subnets, IAM roles, node group, and interface VPC endpoint for private API access
Attaches necessary IAM policies for cluster and nodes, optionally uses custom AMI via launch template
Configures admin access with current AWS user’s ARN and Kubernetes provider using EKS auth token
Ensures secure, private connectivity and automated node bootstrapping

Bastion Host 
============
Creates a public bastion host with open SSH (22), HTTP (80), HTTPS (443), and Kubernetes API (6443) ports, allowing internet access
Creates a private bastion host in a private subnet, accessible only via the public bastion’s SSH, with tools (kubectl, aws-iam-authenticator, AWS CLI) installed
Enables secure SSH jump from local → public bastion → private bastion to manage the EKS cluster

Usage Workflow
===============
SSH from your local machine → Public Bastion Host (public subnet)
  #ssh -i eks-terraform-key.pem ec2-user@65.2.39.90

From Public Bastion → SSH into Private Bastion Host (private subnet)
  10.0.1.164 ]# ssh -i eks-terraform-key.pem ec2-user@10.0.10.107

From Private Bastion → Manage EKS cluster with installed tools (kubectl, AWS CLI, etc.)
  10.0.10.107 ]# Configure terraform-user accesskey and secrect accesskey

How to Connect to Cluster (Make sure you are on private subnet instance)
=====================================

[root@ip-10-0-10-107 ~]# aws eks update-kubeconfig --region ap-south-1 --name private-eks-cluster
Added new context arn:aws:eks:ap-south-1:533267238276:cluster/private-eks-cluster to /root/.kube/config

[root@ip-10-0-10-107 ~]# kubectl get node
NAME                                        STATUS   ROLES    AGE   VERSION
ip-10-0-10-97.ap-south-1.compute.internal   Ready    <none>   91m   v1.31.11-eks-3abbec1