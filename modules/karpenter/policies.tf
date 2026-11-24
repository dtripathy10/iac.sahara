# IAM policies translated from the Karpenter v1.15.3 AWS bootstrap template.
data "aws_region" "current" {}

resource "aws_iam_policy" "controller" {
  for_each = toset([
    "NodeLifecycle",
    "IAMIntegration",
    "EKSIntegration",
    "Interruption",
    "ZonalShift",
    "ResourceDiscovery",
  ])

  name = "KarpenterController${each.key}Policy-${var.cluster_name}"
  policy = jsonencode(jsondecode(templatefile("${path.module}/policies/${each.key}.json.tftpl", {
    partition              = data.aws_partition.current.partition
    region                 = data.aws_region.current.region
    account_id             = data.aws_caller_identity.current.account_id
    cluster_name           = var.cluster_name
    node_role_arn          = aws_iam_role.node.arn
    interruption_queue_arn = aws_sqs_queue.interruption.arn
  })))
  tags = var.tags
}
