#
# The default AssumeRole Policy to be attached to the MSK Cluster
#
data "aws_iam_policy_document" "default-msk-policy" {

  for_each = {
    for k,v in var.msk_config:
      k => v if (
        (
          try(v["cluster"]["create"], false) == true
        ) && (
          try(v["cluster"]["mode"], "provisioned") == "provisioned"
        )
      )
  }

  statement {
    sid = "defaultMSK"

    actions = [
      "kafka:Describe*",
      "kafka:Get*",
      "kafka:CreateVpcConnection",
      "kafka:GetBootstrapBrokers",
    ]

    resources = [
      aws_msk_cluster.msk-cluster[each.key].arn
    ]

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [
        format("arn:%s:iam::%s:root", data.aws_partition.session.partition, data.aws_caller_identity.session.account_id)
      ]
    }

  }
  version        = "2012-10-17"
}

#
# AWS MSK Policy
#
data "aws_iam_policy_document" "msk-policy" {

  for_each = {
    for k,v in var.msk_config:
      k => v["cluster"]["policy"] if try(v["cluster"]["policy"], null) != null
  }

  dynamic "statement" {
    for_each = each.value

    content {
      actions = statement.value["actions"]
      
      dynamic "condition" {
        for_each = coalesce(statement.value["condition"], [])
        content {
          test     = condition.value["test"]
          variable = condition.value["variable"]
          values   = condition.value["values"]
        }
      }
      
      effect  = statement.value["effect"]
      not_actions = statement.value["not_actions"]
      
      dynamic "not_principals" {
        for_each = coalesce(statement.value["not_principals"], [])
        content {
          type        = not_principals.value["type"]
          identifiers = not_principals.value["identifiers"]  
        }
      }

      dynamic "principals" {
        for_each = coalesce(statement.value["principals"], [])
        content {
          type        = principals.value["type"]
          identifiers = principals.value["identifiers"]  
        }
      }

      sid = statement.value["sid"]
    }
  }
}

#
# Deploy MSK Policy
#
#resource "aws_msk_cluster_policy" "msk-policy" {
#  for_each = {
#    for k,v in var.msk_config:
#      k => v if (
#        (
#          try(v["cluster"]["create"], false) == true
#        ) && (
#          try(v["cluster"]["mode"], "provisioned") == "provisioned"
#        )
#      )
#  }
# 
#  cluster_arn = aws_msk_cluster.msk-cluster[each.key].arn
#
#  policy = coalesce(
#    try(
#      data.aws_iam_policy_document.msk-policy[each.key].json,
#      null
#    ),
#    data.aws_iam_policy_document.default-msk-policy[each.key].json
#  )
#}