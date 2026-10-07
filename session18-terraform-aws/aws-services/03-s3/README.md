# Amazon S3 - Simple Storage Service

**Student:** Bhuvanesh M S | **Enrollment:** 24bcs10134 | **Session 18:** Terraform & IaC - AWS services research

---

## 1. What is S3?

Amazon Simple Storage Service (S3) is AWS's **object storage** service. It stores any amount of data as objects inside buckets and serves them over HTTPS through an API. S3 is designed for **99.999999999% (11 nines) durability** of objects, by storing data redundantly across multiple Availability Zones (except the One Zone classes).

Important characteristics:

- **Object storage, not a file system or disk.** There are no real folders; a "folder" is just a key prefix such as `logs/2026/`.
- **Virtually unlimited capacity**; I pay only for what I store and the requests I make.
- **Strong read-after-write consistency** for all PUT, DELETE and LIST operations (since December 2020).
- **Regional service**: a bucket is created in one region, but bucket names are **globally unique** across all AWS accounts.
- **Secure by default** on new buckets: Block Public Access on, ACLs disabled, and SSE-S3 encryption applied to all new objects.

```text
  AWS Region: ap-south-1
  +--------------------------------------------------------------+
  | Bucket: bhuvanesh-devops-s18-dev-1a2b3c4d                    |
  |   settings: versioning | encryption | lifecycle | policy    |
  |                                                              |
  |   key: index.txt               -> object (data + metadata)   |
  |   key: images/logo.png         -> object                     |
  |   key: logs/2026/10/app.log    -> object                     |
  |                 \_______/                                    |
  |                 "folders" are only key prefixes              |
  +--------------------------------------------------------------+
     replicated across >= 3 AZs (except One Zone classes)
```

---

## 2. Core concepts

### Buckets

A **bucket** is the top-level container for objects.

- Name rules: 3-63 characters, lowercase letters, numbers, hyphens and dots; must start and end with a letter or number; must not look like an IP address. Avoid dots if using virtual-hosted-style HTTPS.
- The name is global and cannot be renamed; to "rename" I create a new bucket and copy the data.
- Each account has a default quota of 10,000 general purpose buckets (it can be increased).
- Bucket types:
  - **General purpose buckets** - the normal bucket type, supporting all storage classes except Express One Zone.
  - **Directory buckets** - used by S3 Express One Zone for single-digit-millisecond latency in one AZ.
  - Specialised types also exist, such as **table buckets** (Apache Iceberg tables) and **vector buckets**.

### Objects

An **object** is a file plus its metadata, identified by a **key** inside a bucket.

| Part | Description |
|------|-------------|
| Key | Full name, e.g. `images/2026/logo.png` |
| Value | The data, from 0 bytes up to **5 TB** |
| Version ID | Set when versioning is enabled |
| Metadata | System metadata (Content-Type, Last-Modified, ETag) and user metadata (`x-amz-meta-*`) |
| Tags | Up to 10 key-value tags per object, usable in lifecycle rules and IAM conditions |

- A single PUT can upload up to **5 GB**; larger objects must use **multipart upload** (recommended for anything above about 100 MB).
- Every object has an address: `s3://bucket/key` or `https://bucket.s3.ap-south-1.amazonaws.com/key`.

### Storage classes

| Storage class | AZs | Retrieval | Min. storage duration | Best for |
|---------------|-----|-----------|-----------------------|----------|
| **S3 Standard** | >= 3 | milliseconds | none | Frequently accessed data (default) |
| **S3 Intelligent-Tiering** | >= 3 | milliseconds (optional archive tiers are slower) | none | Unknown or changing access patterns; small monthly monitoring fee per object, moves data between tiers automatically |
| **S3 Express One Zone** | 1 | single-digit milliseconds | none | Latency-sensitive workloads such as ML training and analytics; uses directory buckets |
| **S3 Standard-IA** | >= 3 | milliseconds, per-GB retrieval fee | 30 days | Infrequently accessed data that needs fast access (backups) |
| **S3 One Zone-IA** | 1 | milliseconds, per-GB retrieval fee | 30 days | Re-creatable infrequent data; lower cost, lost if the AZ is destroyed |
| **S3 Glacier Instant Retrieval** | >= 3 | milliseconds | 90 days | Archive data accessed about once a quarter |
| **S3 Glacier Flexible Retrieval** | >= 3 | minutes to hours (expedited 1-5 min, standard 3-5 h, bulk 5-12 h) | 90 days | Archives accessed rarely, backups |
| **S3 Glacier Deep Archive** | >= 3 | within 12 h (standard), within 48 h (bulk) | 180 days | Lowest-cost long-term retention, compliance archives |

Notes: the IA and Glacier Instant Retrieval classes have a minimum billable object size of 128 KB. Objects in Glacier Flexible Retrieval and Deep Archive must be **restored** before they can be read.

```text
 cost per GB stored:   high  -------------------------------------->  low
                       Standard > Standard-IA > One Zone-IA > Glacier IR > Glacier Flexible > Deep Archive
 access speed/cost:    fast, cheap requests  ------------------->  slow, retrieval fees
```

### Versioning

**Versioning** keeps multiple versions of an object in the same bucket.

- Bucket states: **Unversioned** (default) -> **Enabled** -> **Suspended**. Once enabled, a bucket can never go back to unversioned, only suspended.
- Overwriting an object creates a new version; the old one becomes a **noncurrent version**.
- Deleting an object without a version ID adds a **delete marker**; the data is still there and can be recovered by deleting the marker.
- Each version is billed as a full object, so versioning should be combined with lifecycle rules for noncurrent versions.
- **MFA Delete** (configurable only by the root user via the CLI/API) requires MFA to permanently delete versions or change versioning state.
- Versioning is required for **replication** (Cross-Region / Same-Region Replication) and for **Object Lock**.

### Lifecycle policies

A **lifecycle configuration** is a set of rules that S3 applies automatically to objects matching a filter (prefix, tags, or object size).

| Action | Example |
|--------|---------|
| Transition current versions | move `logs/` to Standard-IA after 30 days, Glacier Flexible Retrieval after 90 days |
| Expire current versions | delete `tmp/` objects after 7 days |
| Transition / expire noncurrent versions | delete old versions 30 days after they become noncurrent |
| Abort incomplete multipart uploads | clean up failed uploads after 7 days |
| Remove expired delete markers | tidy versioned buckets |

Objects must stay in S3 Standard for at least 30 days before a lifecycle rule can move them to Standard-IA or One Zone-IA.

### Encryption

**At rest (server-side):**

| Option | Keys managed by | Notes |
|--------|-----------------|-------|
| **SSE-S3** | Amazon S3 (AES-256) | **Default for all new objects since 5 January 2023**, no extra cost |
| **SSE-KMS** | AWS KMS (AWS managed or customer managed key) | Key policies, CloudTrail audit of key use; enable **S3 Bucket Keys** to reduce KMS request costs |
| **DSSE-KMS** | AWS KMS | Dual-layer encryption for strict compliance requirements |
| **SSE-C** | Customer supplies the key on every request | S3 does not store the key |

**Client-side encryption:** data is encrypted before upload (for example with the AWS Encryption SDK), so S3 only stores ciphertext.

**In transit:** HTTPS (TLS). A bucket policy with the condition `aws:SecureTransport = false` -> `Deny` enforces it.

### Bucket policies and access control

S3 access is controlled by several layers:

| Mechanism | Description |
|-----------|-------------|
| **IAM policies** | Attached to users/roles in my account |
| **Bucket policy** | Resource-based JSON policy on the bucket; can grant access to other accounts, services (e.g. CloudFront) or enforce conditions |
| **Block Public Access** | Account- and bucket-level guardrails that override any policy or ACL that would make data public. **On by default for new buckets since April 2023** |
| **Object Ownership / ACLs** | Since April 2023 new buckets use *Bucket owner enforced*, which **disables ACLs**; AWS recommends keeping them disabled |
| **Access points** | Named endpoints with their own policies for large shared datasets |
| **Presigned URLs** | Time-limited URL to GET or PUT one object without AWS credentials |

Example bucket policy that denies any request not using HTTPS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::bhuvanesh-devops-s18-dev-1a2b3c4d",
        "arn:aws:s3:::bhuvanesh-devops-s18-dev-1a2b3c4d/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

---

## 3. AWS CLI examples (v2)

```bash
B=bhuvanesh-demo-$RANDOM

# Create a bucket (outside us-east-1 a LocationConstraint is required with s3api)
aws s3 mb s3://$B --region ap-south-1

# Upload, list, download, sync
aws s3 cp index.txt s3://$B/
aws s3 ls s3://$B/
aws s3 cp s3://$B/index.txt ./downloaded.txt
aws s3 sync ./site s3://$B/site --delete

# Upload directly into a cheaper storage class
aws s3 cp backup.tar.gz s3://$B/backups/ --storage-class STANDARD_IA

# Enable versioning and list versions
aws s3api put-bucket-versioning --bucket $B \
  --versioning-configuration Status=Enabled
aws s3api list-object-versions --bucket $B --prefix index.txt

# Inspect security settings
aws s3api get-bucket-encryption   --bucket $B
aws s3api get-public-access-block --bucket $B
aws s3api get-bucket-ownership-controls --bucket $B

# Apply a lifecycle configuration and a bucket policy from JSON files
aws s3api put-bucket-lifecycle-configuration --bucket $B \
  --lifecycle-configuration file://lifecycle.json
aws s3api put-bucket-policy --bucket $B --policy file://policy.json

# Presigned URL valid for 1 hour
aws s3 presign s3://$B/index.txt --expires-in 3600

# Delete everything and remove the bucket
aws s3 rb s3://$B --force
```

Note: `aws s3 rb --force` deletes current objects only. In a versioned bucket, old versions and delete markers must also be removed before the bucket can be deleted (or use Terraform `force_destroy`, as in my Task 1).

---

## 4. Terraform example

My full working example is in [`../../terraform-s3-demo/`](../../terraform-s3-demo/README.md). The snippet below adds a lifecycle rule and an HTTPS-only bucket policy on top of it:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    id     = "logs-tiering"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"   # Glacier Flexible Retrieval
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.demo]
}

data "aws_iam_policy_document" "https_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.demo.arn,
      "${aws_s3_bucket.demo.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "demo" {
  bucket = aws_s3_bucket.demo.id
  policy = data.aws_iam_policy_document.https_only.json
}
```

Storage class names used in the API and Terraform: `STANDARD`, `INTELLIGENT_TIERING`, `STANDARD_IA`, `ONEZONE_IA`, `GLACIER_IR`, `GLACIER`, `DEEP_ARCHIVE`, `EXPRESS_ONEZONE`.

---

## 5. Best practices

1. **Keep Block Public Access on** at the account and bucket level. Serve public websites through **CloudFront with Origin Access Control** instead of a public bucket.
2. **Keep ACLs disabled** (Object Ownership = Bucket owner enforced) and control access with IAM and bucket policies.
3. **Use least-privilege policies** scoped to specific buckets and prefixes.
4. **Encrypt**: SSE-S3 is automatic; use SSE-KMS with Bucket Keys when I need key-level control and auditing. Enforce HTTPS.
5. **Enable versioning** for important data, plus lifecycle rules to expire noncurrent versions.
6. **Use lifecycle rules or Intelligent-Tiering** to reduce storage cost, and abort incomplete multipart uploads.
7. **Protect critical data** with replication (CRR/SRR), Object Lock (WORM) or AWS Backup.
8. **Monitor and audit**: CloudTrail data events, server access logs, S3 Storage Lens, and IAM Access Analyzer for S3.
9. **Never store Terraform state or secrets in a public bucket**; state buckets should be private, versioned and encrypted.

---

## 6. Common use cases

- Static website assets and media served through CloudFront
- Backup, restore and disaster recovery
- Data lakes and analytics (Athena, EMR, Redshift Spectrum, Glue)
- Log storage (CloudTrail, ALB, VPC Flow Logs)
- Application file uploads (images, documents) using presigned URLs
- Long-term archives and compliance retention with Glacier classes and Object Lock
- Terraform remote state backend
- Build artifacts for CI/CD pipelines and ML training datasets

---

## 7. Free tier notes

- **Legacy Free Tier** (accounts created before 15 July 2025, first 12 months): 5 GB of S3 Standard storage, 20,000 GET requests and 2,000 PUT/COPY/POST/LIST requests per month, plus data transfer out allowances.
- **New accounts (from 15 July 2025)** use the credit-based Free Tier; S3 usage is paid from the sign-up credits.
- Data transfer **into** S3 is free; transfer out to the internet is charged beyond the free allowance.
- Hidden costs to watch: noncurrent versions in versioned buckets, incomplete multipart uploads, retrieval fees and minimum durations for IA/Glacier classes, and KMS request costs with SSE-KMS (reduced by Bucket Keys).

---

## 8. Interview questions

**Q1. How is S3 different from EBS and EFS?**
S3 is object storage accessed through an HTTP API, with virtually unlimited capacity and regional durability. EBS is block storage attached to one EC2 instance in one AZ, used like a disk. EFS is a managed NFS file system that many instances can mount at once.

**Q2. I deleted a file in a versioned bucket. Is it gone?**
No. Deleting without a version ID only adds a delete marker, which becomes the current version. The previous versions are still stored, and removing the delete marker restores the object. Only deleting a specific version ID removes data permanently.

**Q3. How would you make a website hosted in S3 public safely?**
Keep the bucket private with Block Public Access on, put a CloudFront distribution in front of it, and use Origin Access Control with a bucket policy that allows only that distribution to read objects. This also adds HTTPS, caching and a custom domain.

**Q4. What is the difference between SSE-S3 and SSE-KMS?**
Both encrypt objects at rest with AES-256. With SSE-S3, S3 fully manages the keys at no extra cost. With SSE-KMS, the keys are in AWS KMS, so I can control them with key policies, rotate them, and audit every use in CloudTrail; KMS requests are charged (S3 Bucket Keys reduce that cost).

**Q5. How would you reduce storage costs for logs that are rarely read after a month?**
Use a lifecycle rule that transitions them to Standard-IA after 30 days, to Glacier Flexible Retrieval or Deep Archive later, and expires them after the retention period. If access patterns are unpredictable, use Intelligent-Tiering instead.

---

## References

- Amazon S3 User Guide - https://docs.aws.amazon.com/AmazonS3/latest/userguide/
- Storage classes - https://aws.amazon.com/s3/storage-classes/
- Default encryption (SSE-S3) announcement - https://aws.amazon.com/blogs/aws/amazon-s3-encrypts-new-objects-by-default/
- Block Public Access and ACLs disabled by default - https://aws.amazon.com/blogs/aws/heads-up-amazon-s3-security-changes-are-coming-in-april-of-2023/
- Terraform `aws_s3_bucket` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
