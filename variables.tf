variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (also used as a prefix for related resources)."
  type        = string
  default     = "demo-eks"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane."
  type        = string
  default     = "1.37"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper) instead of one per AZ (more resilient)."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable the private API server endpoint."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public API server endpoint."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Restrict this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_log_types" {
  description = "Control plane log types to send to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Retention for the control plane CloudWatch log group."
  type        = number
  default     = 30
}

variable "node_groups" {
  description = "Map of managed node groups to create."
  type = map(object({
    instance_types = optional(list(string), ["t3.micro"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    disk_size      = optional(number, 50)
    desired_size   = optional(number, 4)
    min_size       = optional(number, 1)
    max_size       = optional(number, 5)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
  default = {
    general = {
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 1
      min_size       = 1
      max_size       = 1
    }
  }
}

variable "addons" {
  description = "Map of EKS managed add-ons. Leave addon_version null to use the default for the cluster version."
  type = map(object({
    addon_version               = optional(string)
    configuration_values        = optional(string)
    service_account_role_arn    = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "PRESERVE")
  }))
  default = {
    vpc-cni                = {}
    kube-proxy             = {}
    coredns                = {}
    metrics-server         = {}
    eks-pod-identity-agent = {}
  }
}

variable "enable_managed_argocd" {
  description = "Create an Argo CD capability managed by Amazon EKS."
  type        = bool
  default     = true
}

variable "argocd_identity_center_region" {
  description = "AWS Region of the Identity Center instance. Defaults to Sydney (ap-southeast-2)."
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = var.argocd_identity_center_region == null ? true : trimspace(var.argocd_identity_center_region) != ""
    error_message = "argocd_identity_center_region must not be empty when set."
  }
}

variable "argocd_admin_user_name" {
  description = "Identity Center UserName to grant the ADMIN role in managed Argo CD."
  type        = string
  default     = "argouser-svc"

  validation {
    condition     = var.argocd_admin_user_name == null || trimspace(var.argocd_admin_user_name) != ""
    error_message = "argocd_admin_user_name must not be empty when set."
  }
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for the managed Argo CD capability."
  type        = string
  default     = "argocd"

  validation {
    condition     = trimspace(var.argocd_namespace) != ""
    error_message = "argocd_namespace must not be empty."
  }
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
