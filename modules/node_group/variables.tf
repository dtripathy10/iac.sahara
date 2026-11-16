variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for the worker nodes."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the node groups."
  type        = list(string)
}

variable "node_groups" {
  description = "Map of managed node groups to create."
  type = map(object({
    instance_types = optional(list(string), ["t3.small"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    disk_size      = optional(number, 50)
    desired_size   = optional(number, 2)
    min_size       = optional(number, 2)
    max_size       = optional(number, 2)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
