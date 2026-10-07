# Amazon DynamoDB and Amazon RDS - Databases on AWS

**Student:** Bhuvanesh M S | **Enrollment:** 24bcs10134 | **Session 18:** Terraform & IaC - AWS services research

AWS offers many purpose-built databases. This page covers the two most commonly used ones: **DynamoDB** (a serverless NoSQL key-value and document database) and **RDS** (managed relational databases using SQL).

---

# Part A - Amazon DynamoDB

## A1. What is DynamoDB?

Amazon DynamoDB is a **fully managed, serverless NoSQL database** that delivers single-digit-millisecond performance at virtually any scale. There are no servers, operating systems or database engines to manage, patch or scale.

- **NoSQL**: instead of fixed tables with joins, data is stored as items accessed by key. Each item can have different attributes (flexible schema). Queries are designed around access patterns, not around normalised tables.
- **Serverless**: no instances to choose; capacity scales automatically (on-demand) or by the units I provision.
- **Highly available**: data is automatically replicated across three Availability Zones in a region.
- **Regional**, with optional **global tables** for multi-region, multi-active replication.

## A2. Core concepts

### Tables, items and attributes

| SQL world | DynamoDB | Description |
|-----------|----------|-------------|
| Table | **Table** | A collection of items. Only the primary key is defined up front. |
| Row | **Item** | A single record; maximum size **400 KB** (including attribute names). |
| Column | **Attribute** | A name-value pair. Items in the same table can have different attributes. |

Attribute data types:

| Category | Types |
|----------|-------|
| Scalar | String (`S`), Number (`N`), Binary (`B`), Boolean (`BOOL`), Null (`NULL`) |
| Document | List (`L`), Map (`M`) - nested JSON-like data |
| Set | String set (`SS`), Number set (`NS`), Binary set (`BS`) |

### Primary key: partition key and sort key

Every table has a primary key that uniquely identifies each item. It can be:

1. **Simple primary key** - a **partition key** only. Each partition key value must be unique.
2. **Composite primary key** - **partition key + sort key**. Many items can share a partition key, but the combination must be unique.

- **Partition key (hash key)**: DynamoDB hashes its value to decide which physical partition stores the item. Choose a **high-cardinality** key (for example `UserId`) so requests are spread evenly and no single partition becomes "hot".
- **Sort key (range key)**: items with the same partition key are stored together, ordered by the sort key. This allows range queries such as `begins_with`, `between`, `>`, `<`.

```text
 Table: Orders     PK = CustomerId (partition key), SK = OrderDate (sort key)

  partition "C#101"                         partition "C#205"
 +--------------------------------------+  +---------------------------------+
 | SK 2026-01-04 | total 450 | status A |  | SK 2026-03-11 | total 99        |
 | SK 2026-02-19 | total 120 | items [] |  +---------------------------------+
 | SK 2026-09-30 | total 799            |
 +--------------------------------------+
  Query: CustomerId = "C#101" AND OrderDate BETWEEN "2026-01-01" AND "2026-06-30"
```

### Secondary indexes

| Index | Keys | When created | Notes |
|-------|------|--------------|-------|
| **Global Secondary Index (GSI)** | any partition key (+ optional sort key) | any time | Separate capacity; eventually consistent reads only; up to 20 per table by default |
| **Local Secondary Index (LSI)** | same partition key, different sort key | only at table creation | Supports strongly consistent reads; up to 5 per table |

### Reading data

- **GetItem** - one item by full primary key (fastest).
- **Query** - all items with one partition key, optionally filtered by sort key condition. Efficient.
- **Scan** - reads the whole table. Expensive on large tables; avoid in hot paths.
- Reads are **eventually consistent by default**; **strongly consistent** reads can be requested (on the table and LSIs) and cost twice as much.

### Capacity modes

| | On-demand | Provisioned |
|--|-----------|-------------|
| How it works | Pay per request (read/write request units); scales instantly | I set read capacity units (RCU) and write capacity units (WCU); optional auto scaling |
| Best for | New or unpredictable workloads, spiky traffic, dev/test | Steady, predictable traffic where I can forecast usage |
| Capacity planning | none | required |
| Notes | AWS recommends on-demand as the default for most workloads | Can switch modes (with limits on how often) |

1 RCU = one strongly consistent read per second (or two eventually consistent) of an item up to 4 KB. 1 WCU = one write per second of an item up to 1 KB.

### Other features

- **TTL** - automatically delete expired items at no cost (sessions, temporary data).
- **DynamoDB Streams** - ordered change log of item modifications; can trigger Lambda.
- **Transactions** - ACID `TransactWriteItems` / `TransactGetItems` across multiple items and tables.
- **Point-in-time recovery (PITR)** - restore to any second in the recovery window (up to the last 35 days), plus on-demand backups.
- **Global tables** - multi-region, multi-active replication.
- **DAX** - in-memory cache for microsecond read latency.
- **Encryption at rest** is always on (AWS owned key by default, or AWS managed / customer managed KMS key).

## A3. DynamoDB use cases

- User profiles, sessions and shopping carts
- Gaming leaderboards and player state
- IoT and time-series style event data with TTL
- Serverless back ends (API Gateway + Lambda + DynamoDB)
- Metadata stores and high-traffic key-value lookups
- **Terraform state locking**: historically a DynamoDB table was used for S3 backend locking; since Terraform 1.10 the S3 backend can lock natively with `use_lockfile = true`, and DynamoDB-based locking is deprecated.

## A4. DynamoDB CLI examples (v2)

```bash
# Create an on-demand table with a composite primary key
aws dynamodb create-table \
  --table-name Orders \
  --attribute-definitions AttributeName=CustomerId,AttributeType=S AttributeName=OrderDate,AttributeType=S \
  --key-schema AttributeName=CustomerId,KeyType=HASH AttributeName=OrderDate,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

aws dynamodb wait table-exists --table-name Orders

# Write an item
aws dynamodb put-item --table-name Orders --item '{
  "CustomerId": {"S": "C#101"},
  "OrderDate":  {"S": "2026-10-07"},
  "Total":      {"N": "450"},
  "Status":     {"S": "PLACED"}
}'

# Read one item by its full key
aws dynamodb get-item --table-name Orders \
  --key '{"CustomerId": {"S": "C#101"}, "OrderDate": {"S": "2026-10-07"}}'

# Query all 2026 orders of one customer
aws dynamodb query --table-name Orders \
  --key-condition-expression "CustomerId = :c AND begins_with(OrderDate, :y)" \
  --expression-attribute-values '{":c": {"S": "C#101"}, ":y": {"S": "2026"}}'

aws dynamodb delete-table --table-name Orders
```

## A5. DynamoDB Terraform example

```hcl
resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST" # on-demand
  hash_key     = "CustomerId"
  range_key    = "OrderDate"

  attribute {
    name = "CustomerId"
    type = "S"
  }

  attribute {
    name = "OrderDate"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "Status"
    range_key       = "OrderDate"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true # uses the AWS managed KMS key
  }

  tags = { Name = "orders" }
}
```

Only attributes used in the table key or index keys are declared in Terraform; all other attributes are schemaless.

---

# Part B - Amazon RDS

## B1. What is RDS?

Amazon Relational Database Service (RDS) is a **managed relational database service**. It runs standard SQL database engines and takes care of provisioning, OS and engine patching, automated backups, monitoring, failover and scaling. I still design the schema, write the SQL and tune queries.

- **Relational database**: data is stored in tables with rows and fixed columns, linked by primary and foreign keys, queried with SQL, with ACID transactions and joins.
- RDS runs inside **my VPC**, usually in **private subnets** defined by a **DB subnet group**.
- I connect using a DNS **endpoint** and the normal engine port (MySQL 3306, PostgreSQL 5432, SQL Server 1433, Oracle 1521).
- I do not get OS-level (SSH) access to the database host.

## B2. Core concepts

### Supported engines

| Engine | Notes |
|--------|-------|
| **Amazon Aurora (MySQL-compatible)** | AWS-built, cloud-native; storage auto-grows and is replicated six ways across three AZs |
| **Amazon Aurora (PostgreSQL-compatible)** | Same architecture, PostgreSQL-compatible; also offers Aurora Serverless v2 |
| **MySQL** | Community edition |
| **MariaDB** | Community fork of MySQL |
| **PostgreSQL** | Community edition |
| **Oracle** | Bring Your Own License or License Included (depending on edition) |
| **Microsoft SQL Server** | Express, Web, Standard and Enterprise editions |
| **IBM Db2** | Added to RDS in late 2023 |

### DB instances

A **DB instance** is an isolated database environment running one engine.

- **Instance class** defines CPU and memory, e.g. `db.t4g.micro` (burstable), `db.m7g.large` (general purpose), `db.r7g.xlarge` (memory optimized).
- **Storage**: General Purpose SSD (gp2/gp3) or Provisioned IOPS SSD (io1/io2); **storage autoscaling** can grow it automatically. (Aurora uses its own cluster storage instead.)
- **Parameter groups** hold engine settings; **option groups** enable extra features for some engines.
- Scaling: change the instance class (vertical, brief downtime or during failover with Multi-AZ) or add read replicas (horizontal for reads).
- Old engine major versions eventually leave standard support; staying on them enrols the database in paid **RDS Extended Support**, so upgrades should be planned.

```text
          Application (EC2 / ECS / Lambda in private subnets)
                 |  writes + reads          | reads only
                 v                          v
   +----------------------------+    +-----------------------+
   | Primary DB instance (AZ-a) |    | Read replica (AZ-c or |
   |  endpoint: mydb.xxxx.rds.. |--->| another region)       |
   +-------------+--------------+    +-----------------------+
                 | synchronous            asynchronous
                 v replication            replication
   +----------------------------+
   | Standby instance (AZ-b)    |  <- Multi-AZ: automatic failover,
   | (not readable)             |     same endpoint after failover
   +----------------------------+
```

### Security

| Layer | How |
|-------|-----|
| Network | Place the DB in private subnets (DB subnet group) and set **Publicly accessible = No**. Use a security group allowing the DB port only from the application's security group. |
| Authentication | Master user plus database users; **IAM database authentication** for MySQL, MariaDB and PostgreSQL; Kerberos/Active Directory for some engines. |
| Secrets | Let RDS **manage the master password in AWS Secrets Manager** (with rotation) instead of hard-coding it. |
| Encryption at rest | AWS KMS encryption of storage, automated backups, snapshots and replicas. Must be chosen **at creation**; an unencrypted DB is encrypted by copying a snapshot with encryption and restoring it. |
| Encryption in transit | SSL/TLS connections; can be enforced with parameters (e.g. `rds.force_ssl` for PostgreSQL). |
| Access control on the service | IAM policies control who can create, modify or delete DB instances. |
| Auditing | CloudTrail for API calls, engine audit logs to CloudWatch Logs, Database Insights / Performance Insights for performance. |

### Backups

| Type | Details |
|------|---------|
| **Automated backups** | Daily snapshot during the backup window plus transaction logs. Retention **1-35 days** (0 disables them). Enables **point-in-time recovery**, typically to within the last five minutes. Deleted with the instance unless retained. |
| **Manual snapshots** | Taken on demand, kept **until I delete them**, can be copied to other regions and shared with other accounts. |
| **AWS Backup** | Central backup policies across services and accounts. |

A restore always creates a **new** DB instance with a new endpoint.

### Multi-AZ

Multi-AZ is for **high availability**, not for scaling reads.

| | Multi-AZ DB instance | Multi-AZ DB cluster |
|--|----------------------|---------------------|
| Topology | 1 primary + 1 standby in another AZ | 1 writer + 2 readable standbys in three AZs |
| Replication | synchronous | semi-synchronous |
| Standby readable? | no | yes |
| Engines | all non-Aurora RDS engines | MySQL and PostgreSQL |

On failure of the primary (or during maintenance), RDS automatically fails over and updates the DNS endpoint to point to the standby, so the application reconnects to the same endpoint. Aurora achieves the same by promoting one of its Aurora Replicas.

### Read replicas

Read replicas are for **scaling read traffic**.

- Created from the primary using **asynchronous** replication, so they can lag slightly behind.
- Each replica has its **own endpoint**; the application must send reads to it.
- Supported for MySQL, MariaDB, PostgreSQL, Oracle and SQL Server (with engine-specific limits); MySQL, MariaDB and PostgreSQL support up to 15 replicas per source.
- Can be in the same AZ, another AZ, or **another region** (cross-region replica for disaster recovery or serving users closer to them).
- A replica can be **promoted** to a standalone database.
- Aurora supports up to 15 Aurora Replicas sharing the same cluster storage, with a reader endpoint that load-balances across them.

### Multi-AZ vs read replicas

| | Multi-AZ | Read replica |
|--|----------|--------------|
| Purpose | availability / automatic failover | read scaling, reporting, DR |
| Replication | synchronous | asynchronous |
| Serves reads | no (DB instance) / yes (DB cluster) | yes |
| Endpoint | same endpoint after failover | separate endpoint |
| Cross-region | no | yes |

## B3. RDS use cases

- Back-end database for web and mobile applications (e-commerce, CMS, ERP, CRM)
- Applications that need **joins, complex queries and ACID transactions** (banking, orders, inventory)
- Lift-and-shift of existing MySQL, PostgreSQL, Oracle or SQL Server databases with AWS DMS
- Reporting workloads offloaded to read replicas
- SaaS platforms with relational data models

## B4. RDS CLI examples (v2)

```bash
# DB subnet group from two private subnets
aws rds create-db-subnet-group \
  --db-subnet-group-name demo-db-subnets \
  --db-subnet-group-description "Private subnets for RDS" \
  --subnet-ids subnet-0aaa1111bbbb2222c subnet-0ddd3333eeee4444f

# Small, private, encrypted PostgreSQL instance with password in Secrets Manager
aws rds create-db-instance \
  --db-instance-identifier demo-postgres \
  --engine postgres \
  --db-instance-class db.t4g.micro \
  --allocated-storage 20 --storage-type gp3 \
  --master-username dbadmin --manage-master-user-password \
  --db-subnet-group-name demo-db-subnets \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --no-publicly-accessible --storage-encrypted \
  --backup-retention-period 7

aws rds wait db-instance-available --db-instance-identifier demo-postgres
aws rds describe-db-instances --db-instance-identifier demo-postgres \
  --query "DBInstances[0].[DBInstanceStatus,Endpoint.Address,MultiAZ]"

# Manual snapshot, read replica, delete
aws rds create-db-snapshot --db-instance-identifier demo-postgres \
  --db-snapshot-identifier demo-postgres-snap-1
aws rds create-db-instance-read-replica \
  --db-instance-identifier demo-postgres-replica \
  --source-db-instance-identifier demo-postgres
aws rds delete-db-instance --db-instance-identifier demo-postgres \
  --final-db-snapshot-identifier demo-postgres-final
```

## B5. RDS Terraform example

```hcl
resource "aws_db_subnet_group" "db" {
  name       = "demo-db-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name   = "demo-db-sg"
  vpc_id = var.vpc_id
}

# Allow PostgreSQL only from the application security group
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.app_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "postgres" {
  identifier     = "demo-postgres"
  engine         = "postgres"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50 # storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "appdb"
  username                    = "dbadmin"
  manage_master_user_password = true # password stored in Secrets Manager

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az                = false # true in production
  backup_retention_period = 7
  deletion_protection     = false # true in production
  skip_final_snapshot     = true  # false in production

  tags = { Name = "demo-postgres" }
}

output "db_endpoint" {
  value = aws_db_instance.postgres.address
}
```

---

# Part C - Choosing between DynamoDB and RDS

| | DynamoDB | RDS |
|--|----------|-----|
| Data model | Key-value / document (NoSQL) | Relational tables (SQL) |
| Schema | Flexible, only keys defined | Fixed schema, enforced by the engine |
| Queries | By key, designed around access patterns; no joins | Ad-hoc SQL, joins, aggregations |
| Scaling | Automatic horizontal scaling, virtually unlimited | Vertical scaling + read replicas (Aurora scales further) |
| Server management | Serverless | Choose instance class, maintenance windows |
| Latency | Single-digit milliseconds at any scale | Depends on instance size and query |
| Availability | 3 AZs automatically | Single-AZ by default; Multi-AZ optional |
| Best for | High-scale, known access patterns, serverless apps | Complex relationships, reporting, existing SQL apps |

## Free tier and cost notes

- **DynamoDB**: has an always-free allowance of 25 GB of storage plus 25 provisioned WCU and 25 provisioned RCU per month (provisioned capacity mode). On-demand mode is billed per request, which is very cheap at lab scale. PITR, backups, global tables and streams reads beyond the free allowance are charged.
- **RDS (legacy Free Tier, accounts created before 15 July 2025, first 12 months)**: 750 hours per month of a Single-AZ micro DB instance (MySQL, MariaDB, PostgreSQL, or SQL Server Express on eligible classes), 20 GB of General Purpose storage and 20 GB of backup storage.
- **New accounts (from 15 July 2025)** use the credit-based Free Tier; RDS usage is paid from the credits.
- Things that cost money quickly: Multi-AZ (doubles instance cost), larger instance classes, Provisioned IOPS, snapshots kept after deleting the DB, Extended Support for old engine versions, and public IPv4 if the DB is made public. I always delete lab databases after use.

---

## Interview questions

**Q1. What is the difference between a partition key and a sort key in DynamoDB?**
The partition key's value is hashed to decide which partition stores the item, and on its own it must be unique. Adding a sort key creates a composite primary key: many items can share one partition key, stored together and ordered by the sort key, which enables efficient range queries with `Query`.

**Q2. When should I choose DynamoDB on-demand vs provisioned capacity?**
On-demand for new, unpredictable or spiky workloads because there is no capacity planning and I pay per request. Provisioned (with auto scaling) for steady, predictable traffic where reserving RCU/WCU is cheaper.

**Q3. What is the difference between RDS Multi-AZ and read replicas?**
Multi-AZ provides high availability: a synchronously replicated standby in another AZ with automatic failover behind the same endpoint. Read replicas provide read scalability: asynchronously replicated copies with their own endpoints, which can be in other regions and can be promoted, but which may lag slightly behind the primary.

**Q4. How do you secure an RDS database?**
Place it in private subnets with `publicly_accessible = false`, allow the DB port only from the application's security group, enable encryption at rest with KMS at creation, enforce TLS, store the master password in Secrets Manager (or use IAM database authentication), enable automated backups and deletion protection, and audit with CloudTrail and engine logs.

**Q5. What is the maximum item size in DynamoDB, and how do you store larger data?**
400 KB per item, including attribute names and values. Larger data, such as images or documents, is stored in S3 and the item keeps only the S3 object key and metadata.

---

## References

- Amazon DynamoDB Developer Guide - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/
- DynamoDB core components - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html
- Amazon RDS User Guide - https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/
- RDS Multi-AZ deployments - https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html
- RDS read replicas - https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html
- Terraform `aws_dynamodb_table` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
- Terraform `aws_db_instance` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
