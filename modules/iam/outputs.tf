output "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = aws_iam_role.cluster.arn

  # Ensure the policy is attached before the cluster uses the role.
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

output "node_role_arn" {
  description = "IAM role ARN for managed node groups."
  value       = aws_iam_role.node.arn

  depends_on = [aws_iam_role_policy_attachment.node]
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler."
  value       = aws_iam_role.cluster_autoscaler.arn

  depends_on = [aws_iam_role_policy.cluster_autoscaler]
}

output "lbc_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  value       = aws_iam_role.lbc.arn

  depends_on = [aws_iam_role_policy_attachment.lbc]
}
