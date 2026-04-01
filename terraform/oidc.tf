# -----------------------------------------------
# GitHub Actions OIDC — Keyless AWS Authentication
# -----------------------------------------------
# Allows GitHub Actions to authenticate with AWS
# using short-lived tokens instead of long-lived
# access keys stored in GitHub Secrets
#
# How it works:
#   GitHub Actions → JWT token → AWS STS → temp credentials (15 min)
#   No keys stored anywhere → auto-expiry → no rotation needed
# -----------------------------------------------

# TLS certificate thumbprint for GitHub OIDC provider
# This is the SHA1 fingerprint of GitHub's OIDC TLS certificate
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# OIDC Provider — tells AWS to trust GitHub Actions tokens
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # GitHub's OIDC audience
  client_id_list = ["sts.amazonaws.com"]

  # TLS thumbprint — verifies GitHub's identity
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# -----------------------------------------------
# GitHub Actions IAM Role
# -----------------------------------------------
# Only YOUR repo + main branch can assume this role
# Any other repo or branch → denied
resource "aws_iam_role" "github_actions" {
  name = "pulselog-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # sts.amazonaws.com must be the audience
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # ONLY this repo + main branch can assume this role
            # change VanshShah174/PulseLog-DevSecOps to your repo
            "token.actions.githubusercontent.com:sub" = "repo:VanshShah174/PulseLog-DevSecOps:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------
# GitHub Actions IAM Policy
# -----------------------------------------------
# Minimal permissions needed for CI pipeline:
#   - ECR: push images
#   - EKS: describe cluster (for kubectl)
resource "aws_iam_policy" "github_actions" {
  name        = "pulselog-github-actions-policy"
  description = "Permissions for GitHub Actions CI pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR login — needed before any docker push
        Sid    = "ECRLogin"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken is account-level, not resource-level
        Resource = "*"
      },
      {
        # ECR push — push images to pulselog repos only
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        # scoped to only pulselog ECR repos — not all repos
        Resource = [
          "arn:aws:ecr:${var.aws_region}:*:repository/pulselog-frontend",
          "arn:aws:ecr:${var.aws_region}:*:repository/pulselog-backend",
        ]
      },
      {
        # EKS describe — needed for aws eks update-kubeconfig
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
