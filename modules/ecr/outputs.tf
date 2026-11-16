output "repository_arns" {
  description = "Map of ECR repository names to their ARNs."
  value       = { for name, repository in aws_ecr_repository.this : name => repository.arn }
}

output "repository_urls" {
  description = "Map of ECR repository names to their registry URLs."
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
}
