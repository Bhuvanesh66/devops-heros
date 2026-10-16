# OPTIONAL EKS cluster (enable_eks = true). Off by default because EKS is not
# free tier: the control plane alone costs about 0.10 USD per hour, plus the
# worker node(s). Turn it on for the demo, run the Helm chart on it, then
# `terraform destroy` the same day.

locals {
  eks_count = var.enable_eks ? 1 : 0
}

data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count = local.eks_count

  name               = "${local.name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  count = local.eks_count

  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  count = local.eks_count

  name     = local.name
  version  = var.eks_version
  role_arn = aws_iam_role.eks_cluster[0].arn

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count = local.eks_count

  name               = "${local.name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = var.enable_eks ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]) : toset([])

  role       = aws_iam_role.eks_node[0].name
  policy_arn = each.value
}

resource "aws_eks_node_group" "default" {
  count = local.eks_count

  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.name}-ng"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = [var.eks_node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  disk_size       = 20

  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_iam_role_policy_attachment.eks_node]
}

# EBS CSI driver so the PostgreSQL PVC can be provisioned on EKS. Without it,
# the PVC stays Pending (a good troubleshooting story, but not for the demo).
#
# The controller gets its own IAM role through EKS Pod Identity. Falling back
# to the node role does not work: AL2023 nodes limit IMDSv2 to one hop, so a
# pod cannot reach the instance metadata and the controller crash-loops with
# "no EC2 IMDS role found".
resource "aws_eks_addon" "pod_identity_agent" {
  count = local.eks_count

  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [aws_eks_node_group.default]
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = local.eks_count

  name               = "${local.name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.eks_count

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  count = local.eks_count

  cluster_name                = aws_eks_cluster.main[0].name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  pod_identity_association {
    service_account = "ebs-csi-controller-sa"
    role_arn        = aws_iam_role.ebs_csi[0].arn
  }

  depends_on = [aws_eks_addon.pod_identity_agent, aws_iam_role_policy_attachment.ebs_csi]
}

# Kept so the node itself can still attach volumes it is told about.
resource "aws_iam_role_policy_attachment" "eks_node_ebs" {
  count = local.eks_count

  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
