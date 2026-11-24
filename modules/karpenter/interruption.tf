
resource "aws_sqs_queue" "interruption" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

data "aws_iam_policy_document" "interruption_queue" {
  policy_id = "EC2InterruptionPolicy"

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyHTTP"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy    = data.aws_iam_policy_document.interruption_queue.json
}

locals {
  interruption_events = {
    scheduled-change = {
      source = "aws.health"
      detail = "AWS Health Event"
    }
    spot-interruption = {
      source = "aws.ec2"
      detail = "EC2 Spot Instance Interruption Warning"
    }
    rebalance = {
      source = "aws.ec2"
      detail = "EC2 Instance Rebalance Recommendation"
    }
    instance-state-change = {
      source = "aws.ec2"
      detail = "EC2 Instance State-change Notification"
    }
    capacity-reservation-interruption = {
      source = "aws.ec2"
      detail = "EC2 Capacity Reservation Instance Interruption Warning"
    }
  }
}

# This creates EventBridge rules that listen for specific AWS events.

/**
Here are the five events, each in one or two lines:

1. Scheduled Change (aws.health): AWS plans maintenance on the infrastructure hosting your 
instance. Karpenter gets the notice via SQS and can replace the node ahead of time.

2. Spot Interruption Warning (aws.ec2): AWS gives a two-minute warning before reclaiming 
a Spot Instance. Karpenter drains the workloads and provisions replacement capacity.

3. Instance Rebalance Recommendation (aws.ec2): AWS signals an elevated risk that a
 Spot Instance will be interrupted. Karpenter can replace the node proactively instead of 
 waiting for termination.

4. Instance State Change (aws.ec2): An instance moves between lifecycle states, such 
as `running` to `stopping`, `stopped` or `terminated`. Karpenter can react to the change, 
though not every state change triggers node replacement.

5. Capacity Reservation Interruption (aws.ec2): An instance running under a 
Capacity Reservation is warned it may be interrupted. Karpenter can start replacement 
capacity to limit disruption.

6. Overall flow: AWS Health/EC2 → EventBridge (matches the five event types) → SQS 
(queues the notifications) → Karpenter (handles node disruption).

**Note:** The rule matches only `source` and `detail-type`, not instance IDs or event statuses, 
and the examples above are event headers rather than full EventBridge payloads.

**/
resource "aws_cloudwatch_event_rule" "interruption" {
  for_each = local.interruption_events

  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail]
  })
  tags = var.tags
}

# This forwards matching EventBridge events to the SQS queue, where Karpenter can consume them.
resource "aws_cloudwatch_event_target" "interruption" {
  for_each = aws_cloudwatch_event_rule.interruption

  rule      = each.value.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.interruption.arn

  depends_on = [aws_sqs_queue_policy.interruption]
}
