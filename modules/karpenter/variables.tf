variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
}
