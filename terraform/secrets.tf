# -----------------------------------------------
# KMS Key — encrypts Secrets Manager secrets
# CKV_AWS_149: must use customer-managed CMK, not default
# -----------------------------------------------
resource "aws_kms_key" "secrets" {
  description             = "KMS key for encrypting Secrets Manager secrets"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "pulselog-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/pulselog-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# -----------------------------------------------
# AWS Secrets Manager — PulseLog DB Credentials
# Replaces static K8s Secret (k8s/backend/secret.yaml)
# ESO syncs this into a K8s Secret automatically
# -----------------------------------------------
resource "aws_secretsmanager_secret" "pulselog_db" {
  name                    = "pulselog/db-credentials"
  description             = "PostgreSQL credentials for PulseLog backend"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.id

  tags = {
    Name = "pulselog-db-credentials"
  }
}

# Seed the secret with initial values
# After first apply, manage values in AWS Console or CLI
# Terraform won't overwrite changes made outside of TF
resource "aws_secretsmanager_secret_version" "pulselog_db" {
  secret_id = aws_secretsmanager_secret.pulselog_db.id

  secret_string = jsonencode({
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = "postgres"
    POSTGRES_DB       = "pulselog_db"
  })

  # Ignore future changes — secrets are managed in AWS after initial seed
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------
# IAM Role for External Secrets Operator
# Uses Pod Identity — same pattern as Karpenter, EBS CSI, ALB
# -----------------------------------------------
resource "aws_iam_role" "external_secrets" {
  name = "pulselog-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_policy" "external_secrets" {
  name        = "pulselog-external-secrets-policy"
  description = "Allow ESO to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        # Scoped to only the PulseLog DB secret — least privilege
        Resource = aws_secretsmanager_secret.pulselog_db.arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        # ESO needs to decrypt the secret using the CMK
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

# -----------------------------------------------
# Pod Identity Association
# Links ESO service account → IAM role
# ESO pods get AWS creds automatically via Pod Identity Agent
# -----------------------------------------------
resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
