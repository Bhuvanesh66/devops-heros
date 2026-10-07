# Terraform: AWS infrastructure

Provisions a small, free-tier-friendly AWS environment that runs TaskFlow from
the GHCR images:

| File | Resources |
|---|---|
| `versions.tf` | Terraform >= 1.6, AWS provider `~> 6.0` (locked in `.terraform.lock.hcl`) |
| `providers.tf` | AWS provider with `default_tags` (Project, Environment, Owner, ManagedBy, Repository), AZ lookup |
| `network.tf` | VPC `10.20.0.0/16`, **two public subnets in two AZs**, Internet Gateway, public route table and associations, locked-down default security group |
| `security.tf` | app security group (HTTP 80 in, optional SSH from listed CIDRs, all egress), IAM role and instance profile (SSM Session Manager + read the artifact bucket) |
| `compute.tf` | EC2 `t3.micro`, Amazon Linux 2023 AMI from the public SSM parameter, IMDSv2 only, encrypted gp3 root volume, `user_data` from `user_data.sh.tftpl` |
| `user_data.sh.tftpl` | installs Docker and the compose plugin, generates the DB password **on the instance**, writes a compose file and starts PostgreSQL + backend + frontend (port 80) |
| `storage.tf` | S3 artifact bucket: versioning, SSE (AES256), public access block, BucketOwnerEnforced, TLS-only bucket policy, lifecycle for old versions. Optional ECR repositories (`enable_ecr`) |
| `eks.tf` | **optional** EKS cluster + managed node group + EBS CSI add-on in the two public subnets (`enable_eks`, off by default) |
| `variables.tf` / `outputs.tf` | inputs with validation, and outputs (`app_url`, `instance_id`, `artifact_bucket`, ...) |
| `terraform.tfvars.example` | example inputs. Copy it to `terraform.tfvars`, which is git-ignored |

## Workflow

Credentials come from the AWS CLI profile or environment variables. Nothing
secret is stored in this folder.

```bash
cd final-devops-project/terraform
cp terraform.tfvars.example terraform.tfvars   # edit: region, allowed_http_cidrs (your IP /32), image_tag

terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
terraform apply tfplan

terraform output app_url        # open it ~3-5 minutes later (user data installs Docker and pulls images)
aws ssm start-session --target "$(terraform output -raw instance_id)"
sudo tail -f /var/log/taskflow-bootstrap.log

terraform destroy               # same day - do not leave it running
```

The GHCR packages must be **public** for the instance to pull them anonymously
(GitHub → Packages → package settings → Change visibility). The alternative is
`enable_ecr = true` with a CI step that pushes to ECR.

For the EKS part of the grading rubric, `terraform apply -var enable_eks=true`
adds the cluster. Then:

```bash
aws eks update-kubeconfig --region <region> --name taskflow-dev
helm upgrade --install taskflow ../helm/taskflow -n taskflow --create-namespace -f ../helm/taskflow/values-dev.yaml \
  --set ingress.enabled=false
```

## Cost notes

| Resource | Cost |
|---|---|
| EC2 t3.micro + 20 GiB gp3 | free tier (750 h/month, 30 GiB EBS) in the first 12 months, otherwise roughly 0.01 USD/hour |
| Public IPv4 address | about 0.005 USD/hour (AWS charges for public IPv4 since 2024) |
| S3 bucket | cents for a few MB of artifacts |
| VPC, subnets, IGW, route table, SG, IAM | free |
| **EKS (optional)** | control plane about 0.10 USD/hour + t3.medium node about 0.04-0.05 USD/hour + EBS. **Not free tier.** Enable it only for the demo |
| NAT gateway | not created on purpose (about 0.045 USD/hour plus data) |

`credit_specification` is `standard`, so the t3 cannot run up "unlimited" CPU
credit charges. `force_destroy` on the bucket lets `terraform destroy` remove
it even if artifacts were uploaded.

## Evidence

<!-- SHOT: 12-terraform-plan -->
<!-- SHOT: 13-terraform-apply -->
<!-- SHOT: 14-aws-console -->
<!-- SHOT: 15-terraform-destroy -->
