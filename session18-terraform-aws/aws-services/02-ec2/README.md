# Amazon EC2 - Elastic Compute Cloud

**Student:** Bhuvanesh M S | **Enrollment:** 24bcs10134 | **Session 18:** Terraform & IaC - AWS services research

---

## 1. What is EC2?

Amazon Elastic Compute Cloud (EC2) provides **resizable virtual servers ("instances") in the cloud**. I choose an operating system image, a hardware size, storage and network settings, and AWS launches the server in a few minutes. I pay only while it runs and can stop, resize or terminate it at any time.

EC2 is **Infrastructure as a Service (IaaS)**: AWS manages the physical hardware and the hypervisor (the Nitro System on current instance types), while I manage the operating system, patches, applications and data.

```text
 Region (ap-south-1)
 +-------------------------------------------------------------+
 |  VPC 10.0.0.0/16                                            |
 |  +---------------- AZ ap-south-1a ----------------+        |
 |  |  Public subnet 10.0.1.0/24                      |        |
 |  |   +------------------------------------------+  |        |
 |  |   | EC2 instance (t3.micro)                  |  |        |
 |  |   |  - AMI: Amazon Linux 2023                |  |        |
 |  |   |  - ENI: private IP 10.0.1.25             |  |        |
 |  |   |         public IP 13.x.x.x               |  |        |
 |  |   |  - Security group: allow 22, 80          |  |        |
 |  |   |  - Key pair: bhuvanesh-key               |  |        |
 |  |   |  - IAM role (instance profile)           |  |        |
 |  |   +-------------------+----------------------+  |        |
 |  |                       | attached                |        |
 |  |               +-------v--------+                |        |
 |  |               | EBS gp3 volume |  (same AZ)     |        |
 |  |               +----------------+                |        |
 |  +-------------------------------------------------+        |
 +-------------------------------------------------------------+
```

---

## 2. Core concepts

### AMI (Amazon Machine Image)

An **AMI** is the template used to launch an instance. It contains:

- a root volume snapshot (operating system and any pre-installed software)
- launch permissions (who can use it)
- block device mappings (which volumes to attach)

Sources of AMIs:

| Source | Examples |
|--------|----------|
| AWS provided | Amazon Linux 2023, Windows Server |
| Vendor / community | Ubuntu (Canonical), Red Hat, Debian, SUSE |
| AWS Marketplace | Pre-configured software, sometimes with a licence fee |
| My own (custom) | Created from my instance with `create-image` or built with EC2 Image Builder / Packer |

AMIs are **regional** and have an ID like `ami-0abc...`. The same OS has a different AMI ID in each region, so in Terraform I look it up with a data source instead of hard-coding it.

### Instance types

The instance type defines CPU, memory, storage and network capacity. The name encodes the details:

```text
   m 7 g . xlarge
   | | |    |
   | | |    +-- size (nano, micro, small, medium, large, xlarge, 2xlarge, ...)
   | | +------- extra attribute (g = AWS Graviton/Arm, i = Intel, a = AMD, n = enhanced networking, d = local NVMe)
   | +--------- generation
   +----------- family
```

| Family | Category | Good for |
|--------|----------|----------|
| **T** (t3, t4g) | General purpose, burstable | Low-traffic websites, dev/test. Uses CPU credits to burst above a baseline. |
| **M** (m7i, m7g, m8g) | General purpose | Balanced CPU/memory: app servers, small databases |
| **C** (c7i, c7g) | Compute optimized | Batch processing, high-performance web servers, gaming servers |
| **R / X** | Memory optimized | In-memory caches, large databases, analytics |
| **I / D** | Storage optimized | High I/O on local NVMe, data warehouses |
| **P / G / Inf / Trn** | Accelerated computing | GPU training/inference, graphics, AWS Inferentia/Trainium ML chips |

Graviton (Arm-based) instances usually give better price-performance if the software supports Arm.

### Key pairs

A **key pair** is used to log in securely:

- AWS stores the **public key** and places it on the instance at launch (in `~/.ssh/authorized_keys` for Linux).
- I keep the **private key** (`.pem` file). AWS does not keep a copy, so if I lose it I cannot download it again.
- Types: **RSA** and **ED25519** (ED25519 is not supported for Windows instances).
- Windows instances use the key to decrypt the Administrator password.

Alternatives that avoid managing SSH keys: **EC2 Instance Connect** (pushes a short-lived key) and **AWS Systems Manager Session Manager** (shell access with no open inbound port at all).

### Security groups

A **security group** is a virtual firewall attached to an instance's network interface (ENI):

- **Allow rules only** - there are no deny rules.
- **Stateful** - if inbound traffic is allowed, the response is allowed out automatically, and vice versa.
- A new security group has **no inbound rules** and **allows all outbound** traffic.
- Rules can reference CIDR blocks, prefix lists or **other security groups** (for example, "allow port 5432 only from the app-server security group").
- One instance can have several security groups; changes apply immediately.

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| SSH | TCP | 22 | my IP `/32` only | admin access |
| HTTP | TCP | 80 | `0.0.0.0/0` | public website |
| HTTPS | TCP | 443 | `0.0.0.0/0` | public website |

### EBS (Elastic Block Store)

**EBS** provides network-attached block storage volumes (virtual disks) for EC2:

- A volume lives in **one Availability Zone** and can only be attached to instances in that AZ.
- Data persists independently of the instance. The root volume is deleted on termination by default (`DeleteOnTermination = true`); extra volumes are kept by default.
- **Snapshots** are incremental point-in-time backups stored durably by AWS at the regional level; they can be copied to other regions and used to create new volumes or AMIs.
- Volumes can be encrypted with AWS KMS; account-level "encryption by default" can be enabled per region.
- Volume size and type can be changed while the volume is in use (Elastic Volumes).

| Volume type | Kind | Typical use |
|-------------|------|-------------|
| **gp3** | General purpose SSD | Default choice. Baseline 3,000 IOPS and 125 MB/s independent of size; more can be provisioned. |
| gp2 | General purpose SSD (previous gen) | IOPS scale with size; gp3 is usually cheaper. |
| **io2 Block Express** / io1 | Provisioned IOPS SSD | Critical databases needing high, consistent IOPS |
| **st1** | Throughput optimized HDD | Big data, log processing (cannot be a boot volume) |
| **sc1** | Cold HDD | Infrequently accessed data, lowest cost (cannot be a boot volume) |

**Instance store** is different: physically attached disks on some instance types that are very fast but **temporary** - data is lost when the instance stops, hibernates or terminates.

### Public vs private IP

| | Private IPv4 | Public IPv4 | Elastic IP |
|--|--------------|-------------|------------|
| Reachable from | inside the VPC (and connected networks) | the internet | the internet |
| Assigned | always, from the subnet CIDR | optionally at launch (subnet setting or launch option) | allocated to my account, then associated |
| On stop/start | **kept** | **released and changes** on start | **kept** |
| On terminate | released | released | stays in my account until released |
| Cost | free | charged | charged |

- The instance OS only sees the **private** IP; the internet gateway performs one-to-one NAT for the public IP.
- **Since 1 February 2024 AWS charges for every public IPv4 address** (in use or idle), including auto-assigned public IPs and Elastic IPs, at $0.005 per IP per hour. This is a good reason to put servers in private subnets behind a load balancer, or to use IPv6.

### Instance lifecycle

```text
                launch
                  |
                  v
             +---------+
             | pending |
             +----+----+
                  |
                  v           reboot
             +---------+  <----------+
   +-------> | running |  -----------+
   |         +----+----+
   |    stop /    |     \  terminate
   |  hibernate   v      \
   |       +----------+   \
   |       | stopping |    \
   |       +----+-----+     v
   |            v       +---------------+
   |       +---------+  | shutting-down |
   +-------| stopped |  +-------+-------+
    start  +----+----+          v
                |          +------------+
                +--------> | terminated |  (permanent; visible for a short time, then gone)
               terminate   +------------+
```

| State | Billed for instance? | Notes |
|-------|----------------------|-------|
| pending | no | instance is being prepared |
| running | **yes** | per-second billing (60 s minimum) for Linux and Windows On-Demand |
| stopping / stopped | no (yes while stopping for hibernation) | EBS volumes and any Elastic IP are still charged |
| shutting-down / terminated | no | root EBS volume deleted by default |
| rebooting | yes | same host, IPs and data kept |

- **Stop**: EBS data kept; the instance usually moves to new hardware on start.
- **Hibernate**: RAM is saved to the encrypted EBS root volume, so applications resume where they left off.
- **Terminate**: permanent deletion. **Termination protection** can prevent accidental termination.

### Instance metadata (IMDSv2)

From inside an instance, `http://169.254.169.254/latest/meta-data/` returns information such as the instance ID and the temporary credentials of the attached IAM role. **IMDSv2** requires a session token obtained with a `PUT` request first, which protects against SSRF attacks. Best practice is to set `http_tokens = "required"` (IMDSv2 only). Amazon Linux 2023 AMIs are configured to require IMDSv2 by default.

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

### Purchasing options

| Option | Best for |
|--------|----------|
| **On-Demand** | Short-term or unpredictable workloads, no commitment |
| **Savings Plans / Reserved Instances** | Steady usage with a 1 or 3 year commitment, large discount |
| **Spot Instances** | Fault-tolerant, flexible jobs; up to 90% cheaper but can be interrupted with a 2-minute warning |
| **Dedicated Hosts / Instances** | Licensing or compliance needs for dedicated hardware |

---

## 3. AWS CLI examples (v2)

```bash
# Latest Amazon Linux 2023 AMI ID (public SSM parameter)
aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameters[0].Value" --output text

# Create a key pair and save the private key
aws ec2 create-key-pair --key-name bhuvanesh-key --key-type ed25519 \
  --query "KeyMaterial" --output text > bhuvanesh-key.pem
chmod 400 bhuvanesh-key.pem

# Create a security group and allow SSH from my IP only
aws ec2 create-security-group --group-name web-sg \
  --description "Web server SG" --vpc-id vpc-0123456789abcdef0
aws ec2 authorize-security-group-ingress --group-id sg-0123456789abcdef0 \
  --protocol tcp --port 22 --cidr 203.0.113.10/32

# Launch an instance with IMDSv2 required
aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type t3.micro \
  --key-name bhuvanesh-key \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-1}]'

# List instances with state and IPs
aws ec2 describe-instances \
  --query "Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]" \
  --output table

# Lifecycle actions
aws ec2 stop-instances      --instance-ids i-0123456789abcdef0
aws ec2 start-instances     --instance-ids i-0123456789abcdef0
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0
```

---

## 4. Terraform example

```hcl
# Look up the latest Amazon Linux 2023 AMI instead of hard-coding an ID
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow HTTP from anywhere and SSH from my IP"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = var.my_ip_cidr # e.g. "203.0.113.10/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "bhuvanesh-key"

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
  EOF

  tags = {
    Name = "web-1"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
```

---

## 5. Best practices

1. **Require IMDSv2** on every instance.
2. **Use IAM roles (instance profiles)** for AWS access; never store access keys on an instance.
3. **Restrict security groups**: no `0.0.0.0/0` on SSH/RDP; prefer Session Manager so no inbound admin port is needed.
4. **Put back-end servers in private subnets**; expose only load balancers publicly. This also reduces public IPv4 charges.
5. **Encrypt EBS volumes** and enable EBS encryption by default for the region.
6. **Back up** with EBS snapshots or AWS Backup, and test restores.
7. **Right-size** using CloudWatch metrics and AWS Compute Optimizer; consider Graviton.
8. **Use Auto Scaling groups across multiple AZs** for high availability, with launch templates.
9. **Patch regularly** (Systems Manager Patch Manager) and use up-to-date AMIs.
10. **Tag everything** and stop or terminate unused instances; release unused Elastic IPs.

---

## 6. Common use cases

- Web and application servers (often behind an Application Load Balancer with Auto Scaling)
- Self-managed databases when a managed service does not fit
- CI/CD build agents (for example Jenkins agents or GitHub self-hosted runners)
- Batch processing and scientific computing (often on Spot Instances)
- Machine-learning training and inference on GPU or Trainium/Inferentia instances
- Lift-and-shift migration of on-premises servers
- Bastion hosts and lab/dev environments

---

## 7. Free tier notes

- AWS changed its Free Tier on **15 July 2025**. Accounts created on or after that date get a credit-based Free Tier (sign-up credits, plus extra credits for trying services) and a free account plan that lasts up to 6 months; eligible small instance types such as `t3.micro` and `t4g.micro` can be used against those credits.
- Accounts created **before 15 July 2025** keep the legacy 12-month offer: 750 hours per month of `t2.micro` or `t3.micro` (depending on region), 30 GB of EBS, and 750 hours of public IPv4 per month.
- Things that are easy to forget and cost money: running instances larger than micro, idle Elastic IPs and public IPv4 addresses, EBS volumes and snapshots left after termination, and NAT gateways.
- I always run `terraform destroy` (or terminate the instance) after a lab and set an AWS Budget alert.

---

## 8. Interview questions

**Q1. What is the difference between stopping and terminating an instance?**
Stopping shuts the instance down but keeps its EBS volumes, private IP and instance ID; I can start it again later and I only pay for storage while it is stopped. Terminating permanently deletes the instance, and by default its root EBS volume; it cannot be restarted.

**Q2. Security group vs Network ACL?**
A security group works at the instance (ENI) level, is stateful and supports only allow rules. A network ACL works at the subnet level, is stateless (return traffic must be allowed explicitly), supports allow and deny rules, and evaluates rules in number order.

**Q3. Why does the public IP of my instance change after stop/start, and how do I keep it fixed?**
An auto-assigned public IPv4 address is released when the instance stops and a new one is assigned on start. To keep a fixed address I allocate an Elastic IP and associate it, or better, place the instance behind a load balancer and use DNS.

**Q4. What is IMDSv2 and why is it important?**
It is version 2 of the instance metadata service. Clients must first get a session token with a `PUT` request and send it as a header on every metadata request. This blocks many SSRF attacks that could otherwise steal the IAM role credentials exposed through metadata.

**Q5. EBS vs instance store?**
EBS is network-attached, persists independently of the instance, can be snapshotted, and survives stop/start. Instance store is physically attached to the host, very fast, but ephemeral: the data is lost when the instance stops, hibernates or terminates. Instance store suits caches and scratch data.

---

## References

- Amazon EC2 User Guide - https://docs.aws.amazon.com/ec2/
- Instance lifecycle - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html
- Amazon EBS volume types - https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html
- Public IPv4 pricing announcement - https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- Terraform `aws_instance` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
