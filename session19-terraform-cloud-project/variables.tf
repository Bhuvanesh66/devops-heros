# variables.tf
# Input variables. Actual values are supplied in terraform.tfvars.
# Every variable has a type, a description and (where it makes sense) a
# validation block, so bad values fail at plan time before AWS is called.

variable "aws_region" {
  description = "AWS region where all resources are created."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a valid AWS region code, for example ap-south-1."
  }
}

variable "project_name" {
  description = "Short project name, used as a prefix for resource names and in the Project tag."
  type        = string
  default     = "s19-cloud-project"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name must be 3-25 characters of lowercase letters, numbers and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment name, used in tags and resource names."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  type        = string
  default     = "10.19.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 28
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix length between /16 and /28 (AWS VPC limits)."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block of the public subnet. Must sit inside vpc_cidr."
  type        = string
  default     = "10.19.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block, for example 10.19.1.0/24."
  }
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet. Leave null to use the first AZ the account has in the region."
  type        = string
  default     = null

  validation {
    condition     = var.availability_zone == null || can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9][a-z]$", var.availability_zone))
    error_message = "availability_zone must be null or an AZ name such as ap-south-1a."
  }
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  description = "The only CIDR allowed to reach port 22. Set this to your own public IP with /32 (check it with: curl https://checkip.amazonaws.com)."
  type        = string
  # 203.0.113.0/24 is a documentation-only range (RFC 5737), so this
  # placeholder matches nobody. Replace it with <your-ip>/32 in terraform.tfvars.
  default = "203.0.113.10/32"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0)) && var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr must be a valid IPv4 CIDR and must not be 0.0.0.0/0 (SSH must never be open to the whole internet)."
  }
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. Restricted to Free Tier eligible types."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t2.micro"], var.instance_type)
    error_message = "instance_type must be a Free Tier eligible type: t3.micro or t2.micro."
  }
}

variable "root_volume_size" {
  description = "Size of the encrypted gp3 root volume in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "root_volume_size must be between 8 and 30 GiB (30 GiB is the EBS Free Tier limit)."
  }
}

variable "key_name" {
  description = "Optional name of an existing EC2 key pair for SSH. Leave null and use SSM Session Manager instead."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name. Environment and a random suffix are appended so the final name is globally unique."
  type        = string
  default     = "bhuvanesh-s19-assets"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.bucket_prefix))
    error_message = "bucket_prefix must be 3-42 characters of lowercase letters, numbers and hyphens, and must start and end with a letter or number."
  }
}
