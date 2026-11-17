variable "region" {
  description = "AWS Region containing the Identity Center instance."
  type        = string
}

variable "admin_user_name" {
  description = "UserName of the existing Identity Center user to grant Argo CD ADMIN access."
  type        = string

  validation {
    condition     = trimspace(var.admin_user_name) != ""
    error_message = "Provide an existing AWS Identity Center UserName."
  }
}
