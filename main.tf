data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  argocd_admin_user_name_provided = var.argocd_admin_user_name != null ? trimspace(var.argocd_admin_user_name) != "" : false
  managed_argocd_configured       = var.enable_managed_argocd && local.argocd_admin_user_name_provided

  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  tags = merge(
    {
      Project     = var.cluster_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "terraform_data" "argocd_configuration" {
  count = var.enable_managed_argocd ? 1 : 0

  input = var.argocd_admin_user_name

  lifecycle {
    precondition {
      condition     = local.argocd_admin_user_name_provided
      error_message = "Set argocd_admin_user_name to an existing Identity Center UserName when enable_managed_argocd is true."
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  name                 = var.cluster_name
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
  tags         = local.tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  cluster_role_arn        = module.iam.cluster_role_arn
  subnet_ids              = module.vpc.private_subnet_ids
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs
  enabled_log_types       = var.enabled_log_types
  log_retention_days      = var.log_retention_days
  tags                    = local.tags

  depends_on = [module.iam]
}

module "node_groups" {
  source = "./modules/node_group"

  cluster_name  = module.eks.cluster_name
  node_role_arn = module.iam.node_role_arn
  subnet_ids    = module.vpc.private_subnet_ids
  node_groups   = var.node_groups
  tags          = local.tags
}

# Add-ons are created after the node groups so CoreDNS has nodes to schedule on.
module "addons" {
  source = "./modules/addons"

  cluster_name = module.eks.cluster_name
  addons       = merge(var.addons, { "eks-pod-identity-agent" = {} })
  tags         = local.tags

  depends_on = [module.node_groups]
}

module "argocd_identity_center" {
  count  = local.managed_argocd_configured ? 1 : 0
  source = "./modules/identity_center"

  region          = var.argocd_identity_center_region != null ? var.argocd_identity_center_region : var.region
  admin_user_name = local.argocd_admin_user_name_provided ? var.argocd_admin_user_name : ""

  depends_on = [terraform_data.argocd_configuration]
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.iam.lbc_role_arn

  depends_on = [module.addons]
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = module.iam.cluster_autoscaler_role_arn

  depends_on = [module.addons]
}

resource "aws_iam_role" "argocd_capability" {
  count = local.managed_argocd_configured ? 1 : 0

  name = "${var.cluster_name}-argocd-capability-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "capabilities.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = local.tags
}

resource "aws_eks_capability" "argocd" {
  count = local.managed_argocd_configured ? 1 : 0

  cluster_name              = module.eks.cluster_name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.argocd_capability[0].arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      namespace = var.argocd_namespace

      aws_idc {
        idc_instance_arn = module.argocd_identity_center[0].instance_arn
        idc_region       = var.argocd_identity_center_region
      }

      rbac_role_mapping {
        role = "ADMIN"

        identity {
          id   = module.argocd_identity_center[0].admin_user_id
          type = "SSO_USER"
        }
      }
    }
  }

  tags = local.tags
}
