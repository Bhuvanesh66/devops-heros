# security.tf
# Security group for the web server: HTTP from anywhere, SSH from one IP only.

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Session 19 web server - HTTP from anywhere, SSH from one admin IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH is limited to var.allowed_ssh_cidr (validated to never be 0.0.0.0/0).
  # Set it to your own IP/32 in terraform.tfvars. SSM Session Manager works
  # without this rule at all, which is the more secure option.
  ingress {
    description = "SSH from the admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound (dnf repos, S3, SSM endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}
