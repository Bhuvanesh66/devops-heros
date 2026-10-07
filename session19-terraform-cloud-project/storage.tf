# storage.tf
# Private, versioned, encrypted S3 bucket plus one object that the EC2
# instance downloads at boot.

# S3 bucket names are global across all AWS accounts, so a random suffix
# is added to avoid name collisions.
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "assets" {
  bucket = local.bucket_name

  # Lets "terraform destroy" delete the bucket even when it still holds
  # objects and old versions. Fine for a demo; never for real data.
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption at rest with S3-managed keys (SSE-S3 / AES256).
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access. The EC2 instance reads the object
# through its IAM role, not through a public URL.
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "banner" {
  bucket       = aws_s3_bucket.assets.id
  key          = local.banner_key
  source       = "${path.module}/files/banner.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/files/banner.html") # re-upload when the file changes

  # Explicit dependency: the object does not reference these resources, but
  # it should only be uploaded once versioning, encryption and the public
  # access block are in place, so it is versioned and encrypted from day one.
  depends_on = [
    aws_s3_bucket_versioning.assets,
    aws_s3_bucket_server_side_encryption_configuration.assets,
    aws_s3_bucket_public_access_block.assets,
  ]
}
