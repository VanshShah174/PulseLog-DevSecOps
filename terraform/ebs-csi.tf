# -----------------------------------------------
# EBS CSI Driver
# Required for PersistentVolumeClaims to provision
# EBS volumes for PostgreSQL StatefulSet
# -----------------------------------------------

# IAM Role for EBS CSI Driver
# Uses Pod Identity — same pattern as Karpenter
resource "aws_iam_role" "ebs_csi" {
  name = "pulselog-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# AWS managed policy for EBS CSI driver
# grants permissions to create/attach/delete EBS volumes
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EBS CSI Driver Addon
# provisioner: ebs.csi.eks.amazonaws.com in StorageClass points to this
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.38.1-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}

# Pod Identity Association
# links ebs-csi-controller-sa → IAM role
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
