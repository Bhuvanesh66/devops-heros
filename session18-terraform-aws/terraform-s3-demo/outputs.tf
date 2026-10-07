# outputs.tf
# Values printed after "terraform apply" and available via "terraform output".

output "bucket_name" {
  description = "Globally unique name of the S3 bucket."
  value       = aws_s3_bucket.demo.bucket
}

output "bucket_arn" {
  description = "Amazon Resource Name (ARN) of the bucket."
  value       = aws_s3_bucket.demo.arn
}

output "bucket_region" {
  description = "AWS region the bucket lives in."
  value       = aws_s3_bucket.demo.region
}

output "versioning_status" {
  description = "Versioning status of the bucket."
  value       = aws_s3_bucket_versioning.demo.versioning_configuration[0].status
}

output "object_key" {
  description = "Key of the sample object uploaded to the bucket."
  value       = aws_s3_object.hello.key
}

output "object_s3_uri" {
  description = "S3 URI of the sample object, usable with the AWS CLI."
  value       = "s3://${aws_s3_bucket.demo.bucket}/${aws_s3_object.hello.key}"
}

output "console_url" {
  description = "Link to the bucket in the AWS Management Console."
  value       = "https://${var.aws_region}.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.demo.bucket}?region=${var.aws_region}"
}
