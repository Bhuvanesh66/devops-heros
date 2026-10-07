# terraform.tfvars
# Values for the input variables. Terraform loads this file automatically.
# No secrets are stored here.

aws_region   = "ap-south-1"
project_name = "s19-cloud-project"
environment  = "dev"

vpc_cidr           = "10.19.0.0/16"
public_subnet_cidr = "10.19.1.0/24"
availability_zone  = null # null = first AZ in the region (ap-south-1a)

# Set this to YOUR public IP with /32 before applying:
#   curl https://checkip.amazonaws.com
# 203.0.113.10 is a documentation-only placeholder address.
allowed_ssh_cidr = "203.0.113.10/32"

instance_type    = "t3.micro"
root_volume_size = 8
key_name         = null # no key pair; I connect with SSM Session Manager

bucket_prefix = "bhuvanesh-s19-assets"
