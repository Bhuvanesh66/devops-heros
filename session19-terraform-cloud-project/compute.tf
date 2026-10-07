# compute.tf
# One Amazon Linux 2023 EC2 instance running nginx in the public subnet.

# Latest Amazon Linux 2023 AMI ID, read from the AWS public SSM parameter,
# so no AMI ID is hard-coded for one region.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value # public, non-secret value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.key_name # null = no key pair, use SSM Session Manager

  # Avoid surprise "unlimited" CPU credit charges on t3.
  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 only: metadata requests must use a session token.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/files/user_data.sh.tftpl", {
    aws_region  = var.aws_region
    bucket_name = aws_s3_bucket.assets.bucket # implicit dependency on the bucket
    banner_key  = local.banner_key            # plain local, NOT a reference to the object
  })
  user_data_replace_on_change = true

  # Explicit dependencies. user_data copies s3://<bucket>/assets/banner.html
  # at boot, but nothing in this block references these resources, so
  # Terraform cannot infer that they must exist first:
  # - aws_s3_object.banner: the object must already be in the bucket
  # - aws_iam_role_policy.s3_read: the role must already allow s3:GetObject
  # - aws_route_table_association.public: the subnet needs its internet
  #   route before boot, or dnf and "aws s3 cp" cannot reach anything
  depends_on = [
    aws_s3_object.banner,
    aws_iam_role_policy.s3_read,
    aws_route_table_association.public,
  ]

  # A new AL2023 release changes the SSM parameter; without this the next
  # apply would replace the instance. I prefer to roll the AMI on purpose.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${local.name_prefix}-web"
  }
}
