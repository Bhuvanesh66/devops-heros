# versions.tf
# Pins the Terraform CLI version and the providers this project needs.
#
# - hashicorp/aws    : creates the VPC, EC2, S3 and IAM resources
# - hashicorp/random : generates the random suffix for the globally unique bucket name

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

  # No backend block: state is stored locally in terraform.tfstate.
  # See README section "Terraform state" for the remote S3 backend I would use next.
}
