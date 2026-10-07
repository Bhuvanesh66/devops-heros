# variables.tf
# Input variables for the S3 demo. Values are supplied in terraform.tfvars.

variable "aws_region" {
  description = "AWS region where the S3 bucket is created."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a valid AWS region code, for example ap-south-1."
  }
}

variable "bucket_prefix" {
  description = "Prefix for the bucket name. A random suffix is appended so the final name is globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.bucket_prefix))
    error_message = "bucket_prefix must be 3-42 characters of lowercase letters, numbers and hyphens, and must start and end with a letter or number."
  }
}

variable "environment" {
  description = "Deployment environment name, used in tags and in the bucket name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}
