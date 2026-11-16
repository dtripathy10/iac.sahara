output "node_group_names" {
  description = "Names of the managed node groups."
  value       = [for ng in aws_eks_node_group.this : ng.node_group_name]
}

output "node_group_arns" {
  description = "ARNs of the managed node groups, keyed by name."
  value       = { for k, ng in aws_eks_node_group.this : k => ng.arn }
}
