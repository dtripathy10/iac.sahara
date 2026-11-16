data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

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

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.iam.lbc_role_arn

  depends_on = [module.addons]
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = var.ecr_repository_names
  tags             = local.tags
}
