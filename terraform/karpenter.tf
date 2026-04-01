# -----------------------------------------------
# SQS Queue — Spot interruption handling
# Karpenter watches this queue to gracefully drain
# nodes before AWS reclaims Spot instances
# -----------------------------------------------
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "pulselog-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "pulselog-karpenter-interruption"
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# -----------------------------------------------
# EventBridge Rules → SQS
# Sends Spot interruption signals to Karpenter
# -----------------------------------------------
locals {
  karpenter_events = {
    spot_interruption     = { source = ["aws.ec2"],    detail_type = ["EC2 Spot Instance Interruption Warning"] }
    instance_rebalance    = { source = ["aws.ec2"],    detail_type = ["EC2 Instance Rebalance Recommendation"] }
    instance_state_change = { source = ["aws.ec2"],    detail_type = ["EC2 Instance State-change Notification"] }
    scheduled_change      = { source = ["aws.health"], detail_type = ["AWS Health Event"] }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each    = local.karpenter_events
  name        = "pulselog-karpenter-${each.key}"
  description = "Karpenter interruption: ${each.key}"

  event_pattern = jsonencode({
    source      = each.value.source
    detail-type = each.value.detail_type
  })
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = aws_cloudwatch_event_rule.karpenter
  rule     = each.value.name
  arn      = aws_sqs_queue.karpenter_interruption.arn
}

# -----------------------------------------------
# Karpenter IAM Role
# Uses Pod Identity — no OIDC needed
# -----------------------------------------------
resource "aws_iam_role" "karpenter" {
  name = "pulselog-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_policy" "karpenter" {
  name        = "pulselog-karpenter-policy"
  description = "Permissions for Karpenter to provision and manage EC2 nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Sid      = "PassNodeRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.eks_nodes.arn
      },
      {
        Sid    = "SQSInterruption"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Sid      = "Pricing"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter.arn
}

# -----------------------------------------------
# Pod Identity Association
# Links Karpenter service account → IAM role
# Applied after cluster + Pod Identity addon exist
# -----------------------------------------------
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
