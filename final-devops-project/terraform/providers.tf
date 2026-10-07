provider "aws" {
  region = var.aws_region

  # Every taggable resource gets these tags, so the whole project is easy to
  # find in the console and in Cost Explorer.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = "Bhuvanesh M S (24bcs10134)"
      ManagedBy   = "terraform"
      Repository  = "github.com/Bhuvanesh66/devops-heros"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}
