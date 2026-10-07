# provider.tf
# Configures the AWS provider.
#
# Credentials are NOT written here. Terraform picks them up from the
# standard AWS credential chain, for example:
#   export AWS_PROFILE=devops
#   export AWS_REGION=ap-south-1

provider "aws" {
  region = var.aws_region

  # These tags are added automatically to every resource that supports tags.
  default_tags {
    tags = {
      Project     = var.project_name
      Owner       = "Bhuvanesh"
      Session     = "19"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
