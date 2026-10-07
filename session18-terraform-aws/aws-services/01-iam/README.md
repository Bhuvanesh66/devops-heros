# AWS IAM - Identity and Access Management

**Student:** Bhuvanesh M S | **Enrollment:** 24bcs10134 | **Session 18:** Terraform & IaC - AWS services research

---

## 1. What is IAM?

AWS Identity and Access Management (IAM) is the service that controls **who** can access an AWS account (authentication) and **what** they are allowed to do (authorization). Every AWS API call - from the console, the CLI, an SDK or Terraform - is checked by IAM before it is allowed.

Key facts:

- IAM is a **global** service. Users, groups, roles and policies are not tied to a region.
- IAM itself has **no extra charge**.
- By default every request is **denied**. Access exists only when a policy explicitly allows it.
- The **root user** (the email address used to create the account) has unrestricted access and cannot be limited by IAM policies. It should only be used for the few tasks that require it.

```text
            +------------------ AWS Account ------------------+
            |                                                 |
 person --> |  IAM User ----member of----> IAM Group           |
            |     |                           |               |
            |     |  (attached policies)      | (attached     |
            |     v                           v  policies)    |
            |  Permissions  <------------  Policies (JSON)    |
            |     ^                                           |
 service -> |  IAM Role  (assumed via STS, temporary creds)   |
            |                                                 |
            +-------------------------------------------------+
```

---

## 2. Core concepts

### Users

An **IAM user** is an identity that represents one person or one application with **long-term credentials**:

- a console password (for the AWS Management Console), and/or
- up to two **access keys** (access key ID + secret access key) for the CLI/SDK.

Current AWS guidance is to avoid IAM users for people where possible and use **IAM Identity Center** (formerly AWS SSO) with temporary credentials instead. IAM users still make sense for small personal or lab accounts and for a few workloads that cannot use roles.

### Groups

An **IAM group** is a collection of IAM users. Policies attached to a group apply to every user in it.

- A user can belong to several groups (up to 10).
- Groups cannot be nested (no group inside a group).
- A group is **not** an identity: it cannot be named as a principal in a policy and cannot sign in.

Example: `Developers`, `Admins`, `ReadOnlyAuditors`.

### Roles

An **IAM role** is an identity with permissions but **no long-term credentials**. Whoever is allowed to "assume" the role receives **temporary credentials** from AWS STS (Security Token Service), which expire automatically (by default after one hour; the maximum session duration is configurable up to 12 hours).

A role has two policies:

| Part | Answers the question |
|------|----------------------|
| **Trust policy** | *Who* may assume this role? (an AWS service such as `ec2.amazonaws.com`, another account, a federated identity provider such as GitHub Actions OIDC) |
| **Permissions policy** | *What* can the role do once assumed? |

Typical role uses: an EC2 instance profile, a Lambda execution role, cross-account access, and CI/CD pipelines using OIDC instead of stored keys.

### Policies

A **policy** is a JSON document that defines permissions. Each statement contains:

| Element | Meaning | Example |
|---------|---------|---------|
| `Effect` | `Allow` or `Deny` | `"Allow"` |
| `Action` | API operations | `"s3:GetObject"` |
| `Resource` | ARNs the actions apply to | `"arn:aws:s3:::my-bucket/*"` |
| `Condition` (optional) | When the statement applies | source IP, MFA present, tag values |
| `Principal` | Who (only in resource-based and trust policies) | `{"Service": "ec2.amazonaws.com"}` |

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::bhuvanesh-devops-s18-dev-1234abcd",
        "arn:aws:s3:::bhuvanesh-devops-s18-dev-1234abcd/*"
      ]
    }
  ]
}
```

Types of policies:

| Policy type | Attached to | Notes |
|-------------|-------------|-------|
| **AWS managed** | users, groups, roles | Created and maintained by AWS, e.g. `ReadOnlyAccess`, `AmazonS3ReadOnlyAccess`. Convenient but often broader than needed. |
| **Customer managed** | users, groups, roles | Written by me, reusable, versioned. Preferred for least privilege. |
| **Inline** | one user, group or role | Embedded in a single identity; deleted with it. Use rarely. |
| **Resource-based** | a resource (S3 bucket, SQS queue, KMS key, ...) | Contains a `Principal`. Used for cross-account access. A role trust policy is a resource-based policy. |
| **Permissions boundary** | user or role | Sets the *maximum* permissions an identity can have. |
| **SCP / RCP** (AWS Organizations) | accounts / OUs | Guardrails across many accounts; they never grant permissions on their own. |
| **Session policy** | an assumed-role session | Further limits a single session. |

### Permissions and policy evaluation

The effective permission for a request is calculated like this:

```text
            Request arrives
                  |
                  v
   Any explicit "Deny" in any applicable policy? --yes--> DENIED
                  | no
                  v
   Allowed by SCPs / RCPs, permissions boundary,
   session policy (whichever apply)?             --no---> DENIED
                  | yes
                  v
   Any "Allow" in an identity-based or
   resource-based policy?                        --no---> DENIED (implicit deny)
                  | yes
                  v
               ALLOWED
```

Three rules to remember:

1. **Default deny** - nothing is allowed unless something allows it.
2. **Explicit deny always wins** over any allow.
3. Guardrails (SCPs, boundaries) only **limit**; they never grant.

### Least privilege

The principle of least privilege means granting **only the permissions needed to perform a task, and nothing more**. In practice:

- start from zero permissions and add specific actions on specific resource ARNs, instead of `"Action": "*"` and `"Resource": "*"`
- use **IAM Access Analyzer** to generate policies from CloudTrail activity and to find unused access
- check **last accessed** information to remove permissions that are never used
- use conditions (e.g. `aws:MultiFactorAuthPresent`, `aws:SourceIp`, tags) to narrow access further
- give temporary access through roles instead of permanent access through users

---

## 3. Users vs groups vs roles

| | User | Group | Role |
|--|------|-------|------|
| Represents | one person or app | a set of users | a set of permissions to be assumed |
| Credentials | long-term (password, access keys) | none | temporary (STS) |
| Can sign in / call APIs | yes | no | yes, after being assumed |
| Typical use | lab account admin, legacy app | assign permissions to a team | EC2/Lambda/ECS, cross-account, CI/CD, SSO users |

---

## 4. AWS CLI examples (v2)

```bash
# Who am I currently authenticated as?
aws sts get-caller-identity

# Create a group and attach an AWS managed policy
aws iam create-group --group-name Developers
aws iam attach-group-policy \
  --group-name Developers \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# Create a user and add it to the group
aws iam create-user --user-name bhuvanesh-dev
aws iam add-user-to-group --user-name bhuvanesh-dev --group-name Developers

# Create a customer managed policy from a JSON file
aws iam create-policy \
  --policy-name S3ReadOneBucket \
  --policy-document file://s3-read-policy.json

# Create a role that EC2 can assume (trust policy in trust.json)
aws iam create-role \
  --role-name ec2-s3-read-role \
  --assume-role-policy-document file://trust.json

# Assume a role and get temporary credentials
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/ReadOnlyRole \
  --role-session-name demo-session

# Test a policy without running the real action
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/bhuvanesh-dev \
  --action-names s3:GetObject
```

---

## 5. Terraform example

An EC2 role that can read only one S3 bucket, plus a group for developers:

```hcl
# Trust policy: only the EC2 service may assume this role
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "app-s3-read-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# Least-privilege permissions policy
data "aws_iam_policy_document" "s3_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.demo.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.demo.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_read" {
  name   = "app-s3-read"
  policy = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_role_policy_attachment" "app_s3_read" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# Instance profile so an EC2 instance can use the role
resource "aws_iam_instance_profile" "app" {
  name = "app-instance-profile"
  role = aws_iam_role.app.name
}

# A group with an AWS managed read-only policy
resource "aws_iam_group" "developers" {
  name = "Developers"
}

resource "aws_iam_group_policy_attachment" "developers_ro" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
```

Using `aws_iam_policy_document` instead of hand-written JSON strings lets Terraform validate the structure and makes references to other resources easy.

---

## 6. Best practices

1. **Protect the root user.** Enable MFA, do not create root access keys, and use root only for tasks that require it (such as changing the support plan or closing the account).
2. **Use temporary credentials.** Prefer IAM Identity Center for people and IAM roles for workloads. Avoid long-term access keys.
3. **Enable MFA** for every human identity.
4. **Apply least privilege** with customer managed policies scoped to specific actions and ARNs.
5. **Manage permissions through groups or roles**, not by attaching policies to individual users.
6. **Use IAM Access Analyzer** to validate policies, detect resources shared outside the account, and remove unused access.
7. **Rotate or remove access keys** that are old or unused; check the credential report (`aws iam generate-credential-report`).
8. **Never commit credentials** to Git. Use profiles, environment variables, or OIDC federation for CI/CD (for example GitHub Actions assuming a role).
9. **Use conditions** (MFA, source IP, VPC endpoint, tags) for sensitive actions.
10. **Use permissions boundaries and SCPs** when delegating IAM administration or managing many accounts.
11. **Log everything** with AWS CloudTrail so every API call can be audited.

---

## 7. Common use cases

| Use case | IAM feature |
|----------|-------------|
| Give a team read-only console access | Group + `ReadOnlyAccess` managed policy |
| Let an EC2 app read S3 without storing keys | Role + instance profile |
| Lambda writing to DynamoDB | Lambda execution role |
| GitHub Actions deploying with Terraform | Role trusted by the GitHub OIDC provider |
| Auditor from another AWS account | Cross-account role with a trust policy |
| Company login (Google Workspace, Entra ID, Okta) | IAM Identity Center / SAML federation |
| Stop anyone from disabling CloudTrail | Explicit deny in an SCP |

---

## 8. Free tier and cost notes

- IAM, STS and IAM Identity Center have **no additional charge**.
- Costs only come from the resources that identities create or use.
- Basic IAM Access Analyzer checks (external access findings, policy validation) are free; some newer analyzers such as unused-access analysis are paid features.

---

## 9. Interview questions

**Q1. What is the difference between an IAM user and an IAM role?**
A user has long-term credentials (password and/or access keys) and represents one person or application. A role has no long-term credentials; it is assumed by a trusted principal and returns temporary credentials from STS that expire automatically. Roles are preferred for applications and AWS services.

**Q2. If one policy allows `s3:DeleteObject` and another policy denies it, what happens?**
The request is denied. In IAM policy evaluation an explicit `Deny` always overrides any `Allow`.

**Q3. What is a trust policy?**
A resource-based policy attached to a role that defines which principals (AWS services, accounts, users, or federated identities) are allowed to call `sts:AssumeRole` (or the web identity / SAML variants) on that role.

**Q4. How would you give an application running on EC2 access to S3 securely?**
Create an IAM role with a least-privilege policy for the specific bucket, wrap it in an instance profile and attach it to the instance. The SDK automatically fetches rotating temporary credentials from the instance metadata service, so no access keys are stored on the server.

**Q5. What is the difference between an SCP and a permissions boundary?**
Both only set a maximum on permissions and never grant anything. An SCP is part of AWS Organizations and applies to all principals in the member accounts or OUs it is attached to. A permissions boundary is attached to a single IAM user or role inside an account and limits what that identity's own policies can grant.

---

## References

- AWS IAM User Guide - https://docs.aws.amazon.com/IAM/latest/UserGuide/
- Security best practices in IAM - https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- Policy evaluation logic - https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html
- Terraform `aws_iam_role` - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
