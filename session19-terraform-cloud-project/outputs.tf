# outputs.tf
# Values printed after "terraform apply" and available via "terraform output".

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "availability_zone" {
  description = "Availability Zone of the public subnet."
  value       = aws_subnet.public.availability_zone
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 web server."
  value       = aws_instance.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used by the instance."
  value       = aws_instance.web.ami
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 web server."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "URL of the nginx page served by the instance."
  value       = "http://${aws_instance.web.public_ip}"
}

output "bucket_name" {
  description = "Globally unique name of the S3 bucket."
  value       = aws_s3_bucket.assets.bucket
}

output "banner_object_uri" {
  description = "S3 URI of the object the instance downloads at boot."
  value       = "s3://${aws_s3_bucket.assets.bucket}/${aws_s3_object.banner.key}"
}

output "ssm_session_command" {
  description = "Command to open a shell on the instance without SSH."
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.aws_region}"
}
