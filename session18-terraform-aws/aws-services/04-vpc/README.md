# Amazon VPC - Virtual Private Cloud

**Student:** Bhuvanesh M S | **Enrollment:** 24bcs10134 | **Session 18:** Terraform & IaC - AWS services research

---

## 1. What is a VPC?

An Amazon Virtual Private Cloud (VPC) is a **logically isolated private network inside an AWS region**. I choose its IP address range, divide it into subnets, and control routing and firewalls. Resources such as EC2 instances, RDS databases, load balancers and Lambda functions (when VPC-attached) run inside a VPC.

Key facts:

- A VPC belongs to **one region** but spans **all Availability Zones** in that region.
- Every region in an account comes with a **default VPC** (`172.31.0.0/16`) with a public subnet in each AZ, so beginners can launch instances immediately. For real projects I create a custom VPC.
- Creating a VPC, subnets, route tables, internet gateways, security groups and NACLs is **free**. NAT gateways, public IPv4 addresses, interface endpoints, VPN and Transit Gateway are charged.

### Reference architecture

```text
                                Internet
                                    |
                           +--------+--------+
                           | Internet Gateway|
                           +--------+--------+
   VPC 10.0.0.0/16 (ap-south-1)     |
  +---------------------------------+------------------------------------+
  |                                 |                                    |
  |  AZ ap-south-1a                 |              AZ ap-south-1b        |
  | +-----------------------------+ | +-------------------------------+  |
  | | Public subnet 10.0.1.0/24   | | | Public subnet 10.0.2.0/24     |  |
  | |  [ALB node] [NAT Gateway]   |   |  [ALB node]                   |  |
  | |  route: 0.0.0.0/0 -> IGW    |   |  route: 0.0.0.0/0 -> IGW      |  |
  | +-------------+---------------+   +-------------------------------+  |
  |               | NAT                                                  |
  | +-------------v---------------+   +-------------------------------+  |
  | | Private subnet 10.0.11.0/24 |   | Private subnet 10.0.12.0/24   |  |
  | |  [EC2 app] [RDS primary]    |   |  [EC2 app] [RDS standby]      |  |
  | |  route: 0.0.0.0/0 -> NAT GW |   |  route: 0.0.0.0/0 -> NAT GW   |  |
  | +-----------------------------+   +-------------------------------+  |
  |                                                                      |
  |  Every route table also has:  10.0.0.0/16 -> local                   |
  +----------------------------------------------------------------------+
```

---

## 2. Core concepts

### CIDR (Classless Inter-Domain Routing)

A **CIDR block** describes an IP range as `address/prefix-length`. The prefix length is the number of fixed network bits; the remaining bits are for hosts.

| CIDR | Total IPv4 addresses | Usable in an AWS subnet (minus 5 reserved) |
|------|----------------------|---------------------------------------------|
| `10.0.0.0/16` | 65,536 | - (VPC range) |
| `10.0.1.0/24` | 256 | 251 |
| `10.0.1.0/26` | 64 | 59 |
| `10.0.1.0/28` | 16 | 11 |

Rules in AWS:

- VPC IPv4 CIDR size must be between **/16 and /28**.
- Use private (RFC 1918) ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Plan ranges so they **do not overlap** with other VPCs or on-premises networks I may need to connect via peering, Transit Gateway or VPN.
- Secondary IPv4 CIDRs and an IPv6 block can be added later.

AWS reserves **5 addresses in every subnet**. For `10.0.1.0/24`: `.0` network address, `.1` VPC router, `.2` DNS (Amazon-provided resolver), `.3` reserved for future use, `.255` network broadcast (broadcast is not supported but the address is reserved).

### Subnets

A **subnet** is a range of IP addresses inside the VPC that lives in **exactly one Availability Zone**.

- A subnet's CIDR must be within the VPC CIDR and must not overlap other subnets.
- Each subnet is associated with exactly one route table and one network ACL.
- For high availability I create matching subnets in at least two AZs.

### Public vs private subnet

There is no "public" checkbox; the difference comes entirely from the **route table**:

| | Public subnet | Private subnet |
|--|---------------|----------------|
| Default route | `0.0.0.0/0 -> Internet Gateway` | `0.0.0.0/0 -> NAT Gateway` (or no internet route at all) |
| Inbound from internet | possible, if the resource has a public IP and the SG allows it | **not possible** |
| Outbound to internet | directly through the IGW | through the NAT Gateway (outbound only) |
| Typical resources | load balancers, NAT gateways, bastion hosts | application servers, databases, caches, internal services |
| Auto-assign public IPv4 | usually enabled | disabled |

### Route tables

A **route table** contains rules (routes) that decide where network traffic from a subnet is sent.

| Destination | Target | Meaning |
|-------------|--------|---------|
| `10.0.0.0/16` | `local` | Traffic inside the VPC (always present, cannot be removed) |
| `0.0.0.0/0` | `igw-...` | Everything else goes to the internet (public subnet) |
| `0.0.0.0/0` | `nat-...` | Everything else goes through NAT (private subnet) |
| `pl-...` (S3 prefix list) | `vpce-...` | S3 traffic via a gateway endpoint |
| `172.16.0.0/16` | `pcx-...` / `tgw-...` | Peered VPC / Transit Gateway |

- The **most specific route (longest prefix) wins**.
- Every VPC has a **main route table**; subnets without an explicit association use it. Best practice is to keep the main table private and explicitly associate public subnets with a public table.

### Internet Gateway (IGW)

An **Internet Gateway** is a horizontally scaled, highly available VPC component that allows communication between the VPC and the internet.

- One IGW per VPC; no bandwidth limit and **no hourly charge**.
- It performs one-to-one NAT between an instance's private IPv4 and its public IPv4 address.
- A subnet only becomes public when its route table points `0.0.0.0/0` at the IGW **and** the resource has a public IP.
- For IPv6, an **egress-only internet gateway** allows outbound-only IPv6 traffic (the IPv6 equivalent of NAT for private subnets).

### NAT Gateway

A **NAT Gateway** lets resources in private subnets **initiate outbound** connections to the internet (for OS updates, calling external APIs, pulling container images) while blocking connections initiated from the internet.

- A public NAT gateway is created **in a public subnet** with an **Elastic IP**; private subnet route tables point `0.0.0.0/0` to it.
- It is a managed service that lives in **one AZ**. For high availability, create one NAT gateway per AZ and route each private subnet to the NAT gateway in its own AZ (also avoids cross-AZ data charges).
- A **private NAT gateway** (no Elastic IP) exists for connecting to other private networks.
- **Cost:** a NAT gateway is billed **per hour it exists plus per GB of data it processes**, plus the public IPv4 charge for its Elastic IP. For example, in US East (N. Virginia) it is about $0.045 per hour and $0.045 per GB; prices vary by region. It is **not** covered by the Free Tier and is one of the most common surprise charges for students. For S3 and DynamoDB traffic, a free **gateway VPC endpoint** avoids NAT data-processing charges.
- The older alternative, a self-managed **NAT instance**, is cheaper but I would have to manage its availability and patching.

### Security Groups

A **security group** is a stateful firewall attached to an elastic network interface (ENI), such as an EC2 instance, RDS instance or load balancer.

- **Allow rules only.**
- **Stateful**: return traffic for an allowed connection is automatically allowed.
- All rules are evaluated together (no order).
- Can reference other security groups as the source, which is the cleanest way to build tiers (web SG -> app SG -> DB SG).

### Network ACLs (NACLs)

A **network ACL** is an optional, stateless firewall at the **subnet** boundary.

- Has both **allow and deny** rules.
- **Stateless**: return traffic must be explicitly allowed, usually the **ephemeral port range 1024-65535** for responses.
- Rules are numbered and evaluated **from the lowest number upward; the first match wins**. A final `*` rule denies anything not matched.
- The **default NACL allows all** inbound and outbound traffic. A **newly created custom NACL denies all** until rules are added.
- Useful for blocking a specific IP range at the subnet level, which security groups cannot do.

### Security group vs NACL

| | Security Group | Network ACL |
|--|----------------|-------------|
| Level | Instance / ENI | Subnet |
| State | **Stateful** | **Stateless** |
| Rules | Allow only | Allow and deny |
| Evaluation | All rules together | In number order, first match wins |
| Default | New SG: no inbound, all outbound | Default NACL: allow all; custom NACL: deny all |
| Applies to | Only resources it is attached to | Everything in associated subnets |

```text
 Internet -> IGW -> Route table -> [ NACL (subnet, stateless) ] -> [ SG (ENI, stateful) ] -> EC2
```

### Other useful VPC features

| Feature | Purpose |
|---------|---------|
| VPC endpoints (gateway: S3, DynamoDB - free; interface: most other services via PrivateLink - charged) | Reach AWS services privately without internet or NAT |
| VPC peering | Private routing between two VPCs (non-transitive) |
| Transit Gateway | Hub that connects many VPCs and on-premises networks |
| Site-to-Site VPN / Direct Connect | Connect on-premises networks |
| VPC Flow Logs | Capture IP traffic metadata for troubleshooting and security |

---

## 3. AWS CLI examples (v2)

```bash
# Create a VPC and enable DNS hostnames
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=demo-vpc}]' \
  --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'

# Public and private subnets in ap-south-1a
PUB=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a --query Subnet.SubnetId --output text)
PRIV=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 \
  --availability-zone ap-south-1a --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id $PUB --map-public-ip-on-launch

# Internet gateway
IGW=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID

# Public route table with a default route to the IGW
RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id $RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW
aws ec2 associate-route-table --route-table-id $RT --subnet-id $PUB

# Inspect
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query "Subnets[].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]" --output table
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID
aws ec2 describe-network-acls --filters Name=vpc-id,Values=$VPC_ID
```

---

## 4. Terraform example

A two-AZ VPC with public and private subnets. The NAT gateway is behind a variable that defaults to `false` because it is charged by the hour.

```hcl
variable "enable_nat" {
  type    = bool
  default = false # NAT Gateway costs money every hour
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "demo-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1)  # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-${local.azs[count.index]}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 11) # 10.0.11.0/24, 10.0.12.0/24
  availability_zone = local.azs[count.index]
  tags              = { Name = "private-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Optional NAT gateway (single, for cost; use one per AZ in production)
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_default" {
  count                  = var.enable_nat ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Free gateway endpoint so private subnets reach S3 without NAT
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}
```

For production I would normally use the community module `terraform-aws-modules/vpc/aws`, which builds all of this from a few inputs.

---

## 5. Best practices

1. **Plan non-overlapping CIDRs** and leave room for growth (for example a `/16` per VPC, `/24` or larger subnets).
2. **Use at least two AZs** with matching public and private subnets.
3. **Put only load balancers, NAT gateways and bastions in public subnets**; keep applications and databases private.
4. **Use security groups as the main firewall**, referencing other security groups instead of IP ranges. Use NACLs only for coarse subnet-level rules such as blocking an IP range.
5. **Use one NAT gateway per AZ** in production; in labs avoid NAT entirely or destroy it right after use.
6. **Use VPC gateway endpoints for S3 and DynamoDB** to keep traffic private and avoid NAT charges.
7. **Enable VPC Flow Logs** for troubleshooting and security monitoring.
8. **Prefer Session Manager over bastion hosts** so no SSH port needs to be open.
9. **Manage the network as code** (Terraform) so it is reviewable and reproducible.

---

## 6. Common use cases

- Three-tier web application (public ALB, private app tier, private database tier)
- Isolating dev, test and prod environments in separate VPCs or accounts
- Hybrid cloud: connecting an on-premises data centre with Site-to-Site VPN or Direct Connect
- Hosting EKS/ECS clusters with private worker nodes
- Private access to AWS services through VPC endpoints for compliance
- Hub-and-spoke networking for many accounts with Transit Gateway

---

## 7. Free tier and cost notes

- **Free:** VPC, subnets, route tables, internet gateways, security groups, network ACLs, gateway endpoints (S3, DynamoDB), and traffic within the same AZ using private IPs.
- **Charged:** NAT gateways (hourly + per GB), public IPv4 addresses including Elastic IPs (since February 2024), interface endpoints, Transit Gateway, VPN connections, cross-AZ and internet data transfer, and Flow Logs storage.
- In my labs I keep `enable_nat = false` unless I need it and always run `terraform destroy` afterwards.

---

## 8. Interview questions

**Q1. What makes a subnet public?**
Its route table has a route for `0.0.0.0/0` (or `::/0`) pointing to an Internet Gateway. Resources in it also need a public IP address (and permissive security groups) to actually be reachable from the internet.

**Q2. Why do I get only 251 usable IPs in a /24 subnet?**
A /24 has 256 addresses, and AWS reserves 5 in every subnet: the network address, the VPC router, the DNS server, one reserved for future use, and the broadcast address.

**Q3. What is the difference between an Internet Gateway and a NAT Gateway?**
An Internet Gateway allows two-way traffic between the internet and resources with public IPs in public subnets; it is free. A NAT Gateway sits in a public subnet and lets resources in private subnets start outbound connections only; inbound connections from the internet are not possible. It is charged per hour and per GB.

**Q4. My security group allows inbound port 80 but responses do not reach the client. The NACL allows inbound 80. What is wrong?**
NACLs are stateless, so the outbound response traffic must be allowed too. The NACL needs an outbound rule allowing the ephemeral port range (1024-65535) to the client.

**Q5. How can instances in a private subnet access S3 without a NAT Gateway?**
Create a gateway VPC endpoint for S3 and associate it with the private route tables. Traffic to S3 then stays on the AWS network, and gateway endpoints have no charge.

---

## References

- Amazon VPC User Guide - https://docs.aws.amazon.com/vpc/latest/userguide/
- Subnet CIDR blocks and reserved addresses - https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html
- NAT gateways - https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
- Network ACLs - https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html
- VPC pricing - https://aws.amazon.com/vpc/pricing/
- Terraform `aws_vpc` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
