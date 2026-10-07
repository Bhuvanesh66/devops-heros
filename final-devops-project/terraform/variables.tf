variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used as a prefix for every resource."
  type        = string
  default     = "taskflow"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name must be 2-21 lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per availability zone (two AZs)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Provide exactly two public subnet CIDRs (one per AZ)."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the Docker host (t3.micro is free-tier eligible)."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB (free tier covers 30 GiB of gp2/gp3)."
  type        = number
  default     = 20
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach the app on port 80. Narrow this to your own IP (x.x.x.x/32) when possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidrs" {
  description = "CIDRs allowed to SSH (port 22). Empty = no SSH; use SSM Session Manager instead."
  type        = list(string)
  default     = []
}

variable "key_pair_name" {
  description = "Optional existing EC2 key pair name for SSH. Null = no key (SSM only)."
  type        = string
  default     = null
}

variable "ghcr_owner" {
  description = "GitHub user/org that owns the GHCR images (lowercase)."
  type        = string
  default     = "bhuvanesh66"
}

variable "image_tag" {
  description = "Image tag to run on the EC2 host: a commit SHA pushed by CI, or latest."
  type        = string
  default     = "latest"
}

variable "artifact_bucket_force_destroy" {
  description = "Allow terraform destroy to delete the artifact bucket even if it still has objects (handy for a course project)."
  type        = bool
  default     = true
}

variable "enable_ecr" {
  description = "Also create ECR repositories (an alternative registry to GHCR)."
  type        = bool
  default     = false
}

variable "enable_eks" {
  description = "Also create an EKS cluster + managed node group in the two public subnets. NOT free tier (control plane ~0.10 USD/hour plus nodes) - enable only for the demo and destroy right after."
  type        = bool
  default     = false
}

variable "eks_version" {
  description = "Kubernetes version for the optional EKS cluster."
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_type" {
  description = "Instance type for the optional EKS managed node group."
  type        = string
  default     = "t3.medium"
}
