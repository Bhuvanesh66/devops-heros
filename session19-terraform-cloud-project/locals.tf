# locals.tf
# Values computed once and reused across the configuration.

locals {
  # Example: s19-cloud-project-dev
  name_prefix = "${var.project_name}-${var.environment}"

  # Use the AZ from the variable, or fall back to the first AZ that is
  # available in the region (ap-south-1a for ap-south-1).
  availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  # Example: bhuvanesh-s19-assets-dev-1a2b3c4d
  bucket_name = "${var.bucket_prefix}-${var.environment}-${random_id.suffix.hex}"

  # Key of the object that the EC2 instance downloads at boot.
  banner_key = "assets/banner.html"
}

# Data sources are read-only lookups; they create nothing.

data "aws_availability_zones" "available" {
  state = "available"
}
