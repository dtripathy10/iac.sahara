output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN, for IAM Roles for Service Accounts (IRSA)."
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "configure_kubectl" {
  description = "Command to update your local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "argocd_server_url" {
  description = "URL of the EKS-managed Argo CD server, or null when the capability is disabled."
  value       = var.enable_managed_argocd ? aws_eks_capability.argocd[0].configuration[0].argo_cd[0].server_url : null
}
