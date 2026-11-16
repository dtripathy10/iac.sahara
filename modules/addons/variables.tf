variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "addons" {
  description = "Map of EKS managed add-ons. addon_version = null uses the default for the cluster version."
  type = map(object({
    addon_version = optional(string)
  }))
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
