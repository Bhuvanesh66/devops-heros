# main.tf
# Creates a private, versioned, encrypted S3 bucket and uploads one small
# text file into it.

# S3 bucket names are global across all AWS accounts, so a random suffix
# is added to avoid name collisions.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # Example result: bhuvanesh-devops-s18-dev-1a2b3c4d
  bucket_name = "${var.bucket_prefix}-${var.environment}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "demo" {
  bucket = local.bucket_name

  # Allows "terraform destroy" to delete the bucket even when it still
  # contains objects (and old object versions). Fine for a demo; do not
  # use this on buckets that hold real data.
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

# Keep every version of every object, so overwritten or deleted files
# can be recovered.
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption at rest with S3-managed keys (SSE-S3 / AES256).
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access to this bucket.
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload a small text file so there is something to inspect with
# terraform show, terraform output and the AWS CLI.
resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.demo.id
  key          = "index.txt"
  source       = "${path.module}/files/index.txt"
  content_type = "text/plain"
  etag         = filemd5("${path.module}/files/index.txt")

  # Upload only after versioning and encryption are configured.
  depends_on = [
    aws_s3_bucket_versioning.demo,
    aws_s3_bucket_server_side_encryption_configuration.demo,
    aws_s3_bucket_public_access_block.demo,
  ]
}
