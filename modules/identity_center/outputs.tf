output "instance_arn" {
  description = "ARN of the AWS Identity Center instance."
  value       = one(local.instance_arns)
  depends_on  = [terraform_data.instance]
}

output "admin_user_id" {
  description = "Identity Store ID of the configured admin user."
  value       = data.aws_identitystore_user.admin.user_id
}
