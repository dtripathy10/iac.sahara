variable "cluster_name" {
  description = "EKS cluster name, used as a prefix for role names."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
