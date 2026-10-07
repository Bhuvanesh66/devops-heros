terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state by default (this is a course project). For a team, use an S3
  # backend with state locking, e.g.:
  # backend "s3" {
  #   bucket       = "<state-bucket>"
  #   key          = "final-devops-project/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}
