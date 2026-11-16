data "aws_eks_addon_version" "this" {
  for_each = { for k, v in var.addons : k => v if v.addon_version == null }

  addon_name         = each.key
  kubernetes_version = data.aws_eks_cluster.this.version
  most_recent        = false
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name  = var.cluster_name
  addon_name    = each.key
  addon_version = coalesce(each.value.addon_version, data.aws_eks_addon_version.this[each.key].version)

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

}
