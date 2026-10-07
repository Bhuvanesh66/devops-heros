# Session 18 - Terraform & Infrastructure as Code: Homework Submission

| | |
|--|--|
| **Name** | Bhuvanesh M S |
| **Enrollment No.** | 24bcs10134 |
| **Course** | DevOps |
| **Session** | 18 - Terraform & IaC |
| **AWS region used** | ap-south-1 (Mumbai) |

---

## Tasks

1. **Task 1 - Terraform S3 Demo:** Write a Terraform project that creates an AWS S3 bucket, and run the full workflow: `terraform init`, `fmt`, `validate`, `plan`, `apply`, `show`, `output`, `destroy`.
2. **Task 2 - AWS services research:** Write a separate README for IAM, EC2, S3, VPC, and DynamoDB/RDS.

## Status

| # | Deliverable | Location | Status |
|---|-------------|----------|--------|
| 1 | Terraform S3 demo (code + workflow documentation) | [terraform-s3-demo/](terraform-s3-demo/README.md) | Code complete, validated; live run screenshots below |
| 2.1 | IAM research | [aws-services/01-iam/](aws-services/01-iam/README.md) | Complete |
| 2.2 | EC2 research | [aws-services/02-ec2/](aws-services/02-ec2/README.md) | Complete |
| 2.3 | S3 research | [aws-services/03-s3/](aws-services/03-s3/README.md) | Complete |
| 2.4 | VPC research | [aws-services/04-vpc/](aws-services/04-vpc/README.md) | Complete |
| 2.5 | DynamoDB and RDS research | [aws-services/05-dynamodb-rds/](aws-services/05-dynamodb-rds/README.md) | Complete |

## Folder structure

```text
session18-terraform-aws/
|-- README.md                      <- this page
|-- terraform-s3-demo/             <- Task 1
|   |-- provider.tf
|   |-- variables.tf
|   |-- terraform.tfvars
|   |-- main.tf
|   |-- outputs.tf
|   |-- files/index.txt
|   |-- .terraform.lock.hcl
|   |-- .gitignore
|   `-- README.md
`-- aws-services/                  <- Task 2
    |-- 01-iam/README.md
    |-- 02-ec2/README.md
    |-- 03-s3/README.md
    |-- 04-vpc/README.md
    `-- 05-dynamodb-rds/README.md
```

---

## Task 1 - Terraform S3 Demo

The Terraform project creates a private S3 bucket with a globally unique name (`bhuvanesh-devops-s18-dev-<random suffix>`), versioning enabled, SSE-S3 (AES256) default encryption, all Block Public Access settings on, default tags on every resource, and one uploaded object (`index.txt`). It uses the `hashicorp/aws` (~> 6.0) and `hashicorp/random` (~> 3.6) providers, and reads AWS credentials from a named CLI profile, so no secrets are in the code.

Full explanation of every file and every command: **[terraform-s3-demo/README.md](terraform-s3-demo/README.md)**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `terraform init` | Download providers, create the lock file |
| 2 | `terraform fmt` / `terraform validate` | Format code, check syntax and references |
| 3 | `terraform plan` | Preview the 6 resources to be created |
| 4 | `terraform apply` | Create the bucket and related resources |
| 5 | `terraform show` | Inspect what is recorded in state |
| 6 | `terraform output` | Print bucket name, ARN, region and more |
| 7 | `aws s3 ...` / `aws s3api ...` | Verify the bucket from the AWS side |
| 8 | `terraform destroy` | Delete everything that was created |

### Screenshots summary

<!-- SHOT: task1-summary -->

<!-- SHOT: 01-init -->
<!-- SHOT: 02-fmt-validate -->
<!-- SHOT: 03-plan -->
<!-- SHOT: 04-apply -->
<!-- SHOT: 05-show -->
<!-- SHOT: 06-output -->
<!-- SHOT: 07-aws-cli-verify -->
<!-- SHOT: 08-destroy -->

---

## Task 2 - AWS services research

Each README has definitions for every required topic, comparison tables, a diagram, AWS CLI v2 examples, a Terraform snippet, best practices, common use cases, Free Tier notes and five interview questions with answers.

| Service | README | Topics covered |
|---------|--------|----------------|
| IAM | [01-iam](aws-services/01-iam/README.md) | Users, groups, roles, policies, permissions and policy evaluation, least privilege, best practices, use cases |
| EC2 | [02-ec2](aws-services/02-ec2/README.md) | AMI, instance types, key pairs, security groups, EBS, public vs private IP, instance lifecycle, IMDSv2, use cases |
| S3 | [03-s3](aws-services/03-s3/README.md) | Buckets, objects, storage classes, versioning, lifecycle policies, encryption, bucket policies, use cases |
| VPC | [04-vpc](aws-services/04-vpc/README.md) | CIDR, subnets, route tables, internet gateway, NAT gateway, security groups, network ACLs, public vs private subnets |
| DynamoDB and RDS | [05-dynamodb-rds](aws-services/05-dynamodb-rds/README.md) | DynamoDB tables, items, attributes, partition and sort keys, capacity modes; RDS engines, DB instances, security, backups, Multi-AZ, read replicas, use cases |

---

## What I learned

- **Infrastructure as Code makes infrastructure repeatable.** The same `.tf` files create an identical bucket every time, and `terraform destroy` removes everything cleanly, which is much safer than clicking through the console.
- **`plan` before `apply`.** Reading the plan (what will be added, changed or destroyed) is the most important safety check in the workflow.
- **State is central.** Terraform maps my code to real resources through `terraform.tfstate`. State must never be committed to Git, and for team work it belongs in a remote backend with locking.
- **Pin versions.** `required_version`, provider version constraints and the committed `.terraform.lock.hcl` keep everyone on the same tested versions.
- **Secure defaults matter.** Even though S3 now encrypts objects and blocks public access by default, declaring these settings in code documents the intent and lets Terraform correct drift.
- **Never hard-code credentials.** Using an AWS CLI profile (and roles with temporary credentials in real projects) keeps secrets out of the repository.
- **Least privilege and private networking** came up in every service I researched: IAM roles instead of access keys, private subnets for servers and databases, and security groups that reference each other.
- **Cost awareness.** NAT gateways, public IPv4 addresses, Multi-AZ databases and forgotten snapshots are the common surprise charges, so I clean up every lab with `terraform destroy`.
