output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "ecr_frontend_url" {
  description = "ECR URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_url" {
  description = "ECR URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "karpenter_interruption_queue" {
  description = "SQS queue name for Karpenter Spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_role_arn" {
  description = "IAM role ARN for Karpenter"
  value       = aws_iam_role.karpenter.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — use in ci.yml as role-to-assume"
  value       = aws_iam_role.github_actions.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl after apply"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "install_alb_controller" {
  description = "Run this command to install AWS Load Balancer Controller after apply"
  value       = "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --set clusterName=${var.cluster_name} --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller"
}
