# provider.tf
# Pins the Terraform CLI version and the providers this project needs,
# then configures the AWS provider.
#
# Credentials are NOT written here. Terraform picks them up from the
# standard AWS credential chain, for example:
#   export AWS_PROFILE=devops
#   export AWS_REGION=ap-south-1

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # These tags are added automatically to every resource that supports tags.
  default_tags {
    tags = {
      Project     = "terraform-s3-demo"
      Owner       = "Bhuvanesh"
      Session     = "18"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
