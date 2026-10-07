# One t3.micro Docker host running the TaskFlow stack with docker compose.
# The AMI is the latest Amazon Linux 2023, looked up through the public SSM
# parameter instead of a hard-coded (region-specific, soon outdated) AMI ID.

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    ghcr_owner = var.ghcr_owner
    image_tag  = var.image_tag
  })
  # A new image tag means new user data, which means a fresh instance.
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # containers on the host may need IMDS
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard" # never pay for "unlimited" burst on a t3
  }

  tags = {
    Name = "${local.name}-docker-host"
  }

  lifecycle {
    # AL2023 gets a new AMI every few weeks; do not replace the host just for that.
    ignore_changes = [ami]
  }
}
