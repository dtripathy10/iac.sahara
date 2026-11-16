variable "repository_names" {
  description = "Set of ECR repository names to create."
  type        = set(string)
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten (MUTABLE or IMMUTABLE)."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable image vulnerability scanning when images are pushed."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow Terraform to delete repositories that still contain images."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the repositories."
  type        = map(string)
  default     = {}
}
