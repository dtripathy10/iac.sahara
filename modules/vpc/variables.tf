variable "name" {
  description = "Name prefix for VPC resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for Kubernetes subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "azs" {
  description = "Availability zones to use."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per AZ)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (one per AZ)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all private subnets."
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Tag private subnets for Karpenter discovery."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
