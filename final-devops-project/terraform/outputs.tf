output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets."
  value       = aws_subnet.public[*].id
}

output "instance_id" {
  description = "EC2 instance ID (use it with: aws ssm start-session --target <id>)."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the Docker host."
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "TaskFlow UI served by the Docker host (allow a few minutes after apply for user data to finish)."
  value       = "http://${aws_instance.app.public_dns}"
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI resolved from SSM."
  value       = aws_instance.app.ami
  sensitive   = true # the SSM parameter value is marked sensitive by the provider
}

output "artifact_bucket" {
  description = "Name of the versioned, encrypted artifact bucket."
  value       = aws_s3_bucket.artifacts.bucket
}

output "ecr_repository_urls" {
  description = "ECR repository URLs (empty unless enable_ecr = true)."
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "eks_cluster_name" {
  description = "EKS cluster name (null unless enable_eks = true)."
  value       = var.enable_eks ? aws_eks_cluster.main[0].name : null
}

output "eks_kubeconfig_command" {
  description = "Command that writes a kubeconfig entry for the optional EKS cluster."
  value       = var.enable_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main[0].name}" : null
}
