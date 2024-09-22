#
# Provider setting
#
provider "aws" {
  region = var.disaster_recovery_region
  alias  = "dr"
}

#
# Retrieve data from MSK Clusters to deploy replicator
#
data "aws_msk_cluster" "msk-cluster-for-replicator" {

  for_each = zipmap(
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          [
            for y in coalesce(x["kafka_cluster"], []):
              format("%s-%s-%s",
                k,
                x["replicator_name"],
                y["amazon_msk_cluster"]["msk_cluster_name"]
              ) if (
                (
                  y["amazon_msk_cluster"]["msk_cluster_name"] != null
                ) && (
                  y["amazon_msk_cluster"]["region"] == null
                )
              )
          ]
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    ),
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          [
            for y in coalesce(x["kafka_cluster"], []):
              y if (
                (
                  y["amazon_msk_cluster"]["msk_cluster_name"] != null
                ) && (
                  y["amazon_msk_cluster"]["region"] == null
                )
              )
          ]
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    )
  )

  cluster_name = each.value["amazon_msk_cluster"]["msk_cluster_name"]

  depends_on = [
    aws_msk_cluster.msk-cluster
  ]

}

#
# Retrieve data from MSK Clusters to deploy replicator from a remote Region
#
data "aws_msk_cluster" "msk-cluster-for-replicator-remoteregion" {

  for_each = zipmap(
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          [
            for y in coalesce(x["kafka_cluster"], []):
              format("%s-%s-%s",
                k,
                x["replicator_name"],
                y["amazon_msk_cluster"]["msk_cluster_name"]
              ) if (
                (
                  y["amazon_msk_cluster"]["msk_cluster_name"] != null
                ) && (
                  y["amazon_msk_cluster"]["region"] != null
                )
              )
          ]
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    ),
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          [
            for y in coalesce(x["kafka_cluster"], []):
              y if (
                (
                  y["amazon_msk_cluster"]["msk_cluster_name"] != null
                ) && (
                  y["amazon_msk_cluster"]["region"] != null
                )
              )
          ]
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    )
  )

  cluster_name = "sales-dr" #each.value["amazon_msk_cluster"]["msk_cluster_name"]

  depends_on = [
    aws_msk_cluster.msk-cluster
  ]

  provider = aws.dr
}

#
# The default AssumeRole Policy to be attached in the MSK Replicator.
#
data "aws_iam_policy_document" "default-msk-replicator-assume-role-policy" {
  
  statement {
    sid = "DefaultMSKReplicatorAssumeRole"

    actions = [
      "sts:AssumeRole"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"

      values = [
        data.aws_caller_identity.session.account_id
      ]
    }

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }
  }
}

#
# The default AssumeRole Policy to be attached in the MSK Replicator.
#
data "aws_iam_policy_document" "default-msk-replicator-policy" {

  for_each = zipmap(
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          format("%s-%s-%s-%s",
            k,
            x["replicator_name"],
            md5(
              coalesce(
                x["replication_info_list"]["source_kafka_cluster_name"], x["replication_info_list"]["source_kafka_cluster_arn"]
              )
            ),
            md5(
              coalesce(
                x["replication_info_list"]["target_kafka_cluster_name"], x["replication_info_list"]["target_kafka_cluster_arn"]
              )
            )
          )
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    ),
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          merge(
            x,
            {"msk_cluster_name": k}
          )
        ] if (
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    )
  )

  version= "2012-10-17"

  statement {
    sid = "ClusterPermissions"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:WriteDataIdempotently"
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
        )
      )
    ]
  }

  statement {
    sid = "ReadPermissions"
    actions = [
      "kafka-cluster:ReadData",
      "kafka-cluster:DescribeTopic",
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(  
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      )
    ]
  }

 statement {
    sid = "WritePermissions"
    actions = [
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData"
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(  
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      )
    ]
  }

  statement {
    sid = "CreateTopicPermissions"
    actions = [
      "kafka-cluster:ReadData",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData",
      "kafka-cluster:CreateTopic"
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(  
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      ),
      format("arn:aws:kafka:%s:%s:topic/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
        )
      )
    ]
  }  

  statement {
    sid = "GroupPermissions"
    actions = [
	    "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup",
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
        )
      ),
      format("arn:aws:kafka:%s:%s:group/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,          
        )
      ),
      format("arn:aws:kafka:%s:%s:group/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].tags["sg_id"],
        )
      )
    ]
  }

  statement {
    sid = "AlterOperationPermissions"
    actions = [
      "kafka-cluster:AlterTopic",
      "kafka-cluster:AlterCluster"
    ]
    effect = "Allow"
    resources = [
      format("%s", 
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].arn,
        )
      ),
      format("%s",
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].arn,
        )
      ),
      format("arn:aws:kafka:%s:%s:group/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["source_kafka_cluster_name"]
            )
          ].cluster_name,          
        )
      ),
      format("arn:aws:kafka:%s:%s:group/%s/*",
        data.aws_region.session.name,
        data.aws_caller_identity.session.account_id,
        try(
          data.aws_msk_cluster.msk-cluster-for-replicator[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].cluster_name,
          data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              each.value["replication_info_list"]["target_kafka_cluster_name"]
            )
          ].tags["sg_id"],
        )
      )
    ]
  }
}

#
# The MSK Replicator IAM Role.
#
resource "aws_iam_role" "msk-replicator-iamrole" {
  for_each = zipmap(
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          format("%s-%s-%s-%s",
            k,
            x["replicator_name"],
            md5(
              coalesce(
                x["replication_info_list"]["source_kafka_cluster_name"], x["replication_info_list"]["source_kafka_cluster_arn"]
              )
            ),
            md5(
              coalesce(
                x["replication_info_list"]["target_kafka_cluster_name"], x["replication_info_list"]["target_kafka_cluster_arn"]
              )
            )
          )
        ] if (
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    ),
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          merge(
            x,
            {"msk_cluster_name": k}
          )
        ] if (
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    )
  )
  
  assume_role_policy    = data.aws_iam_policy_document.default-msk-replicator-assume-role-policy.json
  description           = format("MSK Replicator for MSK - %s", each.value["msk_cluster_name"])
  force_detach_policies = true
  inline_policy {
    name   = "MSKReplicatorPolicy"
    policy = data.aws_iam_policy_document.default-msk-replicator-policy[each.key].json
  }
  name                  = format("msk-replicator-%s-%s@%s", each.value["msk_cluster_name"], each.value["replicator_name"], time_static.msk-timestamp[each.value["msk_cluster_name"]].unix)
  path                  = "/system/database/"
  #tags =
  lifecycle {
    ignore_changes = [inline_policy] ###################
  }
}

#
# Retrieving Subnets IDs from 
#
data "aws_subnets" "default-msk-replicator-subnets" {
  
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {"msk_cluster_name": k}
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  filter {
    name = "vpc-id"
    values = flatten(
      [
        coalesce(
          data.aws_vpcs.default-msk-vpc[each.value["msk_cluster_name"]].ids,
          data.aws_vpcs.msk-vpc[each.value["msk_cluster_name"]].ids
        )
      ]
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["subnet_filter"],
        null
      ),
      [
        {
          name   = "tag:ops.team/msk/replicator/default"
          values = toset(
            [
              true
            ]
          )
        }
      ]
    )
  
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }  
}

#
# Retrieve Subnet IDs to deploy Endpoint Interfaces
#
data "aws_subnets" "msk-replicator-subnets" {
  for_each =  zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {"msk_cluster_name": k}
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  filter {
    name = "vpc-id"
    values = flatten(
      [
        coalesce(
          data.aws_vpcs.default-msk-vpc[each.value["msk_cluster_name"]].ids,
          data.aws_vpcs.msk-vpc[each.value["msk_cluster_name"]].ids
        )
      ]
    )
  }


  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["subnet_filter"],
        null
      ),
      [
        {
          name = format(
            "tag:ops.team/msk/replicator/%s",
            each.value["msk_cluster_name"]
          )
          values = toset([true])
        }
      ]
    )
  
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }
}


#
# Retrieving Subnets IDs from 
#
data "aws_subnets" "default-msk-replicator-subnets-remoteregion" {
  
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
                
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {"msk_cluster_name": k}
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  filter {
    name = "vpc-id"
    values = flatten(
      [
        coalesce(
          data.aws_vpcs.default-msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids,
          data.aws_vpcs.msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids
        )
      ]
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["subnet_filter"],
        null
      ),
      [
        {
          name   = "tag:ops.team/msk/replicator/default"
          values = toset(
            [
              true
            ]
          )
        }
      ]
    )
  
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }

  provider = aws.dr  
}

#
# Retrieve Subnet IDs to deploy Endpoint Interfaces
#
data "aws_subnets" "msk-replicator-subnets-remoteregion" {
  for_each =  zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {"msk_cluster_name": k}
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  filter {
    name = "vpc-id"
    values = flatten(
      [
        coalesce(
          data.aws_vpcs.default-msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids,
          data.aws_vpcs.msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids
        )
      ]
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["subnet_filter"],
        null
      ),
      [
        {
          name = format(
            "tag:ops.team/msk/replicator/%s",
            each.value["msk_cluster_name"]
          )
          values = toset([true])
        }
      ]
    )
  
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }

  provider = aws.dr
}

#
# AWS MSK Security Groups
#
module "msk-sg-replicator" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  source = "git@github.com:opsteamhub/terraform-aws-vpc.git"

  vpc_config = {
    vpc = {
      create = false
      id     = coalescelist(
          data.aws_vpcs.default-msk-vpc[each.value["msk_cluster_name"]].ids,
          data.aws_vpcs.msk-vpc[each.value["msk_cluster_name"]].ids,
        tolist(
          [
            try(
              each.value["common"]["vpc_config"]["vpc_id"],
              null
            )
          ]
        )
      )
    }
    security_groups = toset(
      [
        merge(
          {
            name = format("msk-replicator-%s", each.key)
          },
          {
            "egress" = [
            ]
          },
          {
            "ingress" = [
            ]
          }
        )
      ]
    )
  }
}


#
# AWS MSK Security Groups in Remote Region for MSK Replicator
#
resource "aws_security_group" "msk-sg-replicator-remoteregion" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  vpc_id  = coalesce(
    try(
      each.value["vpc_config"]["vpc_id"],
      null
    ),
    try(
      element(
        data.aws_vpcs.default-msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids,
        0
      ),
      element(
        data.aws_vpcs.msk-vpc-remoteregion[each.value["amazon_msk_cluster"]["msk_cluster_name"]].ids,
        0
      ),
      null
    )
  )

  name = each.key
  provider = aws.dr
}

#
# Deploying Rule thatg allow Egress from MSK Replicator to MSK Brokers
#
resource "aws_security_group_rule" "sgrule-msk-replicator-allowing-egress-to-sg-msk-broker" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  type                      = "egress"
  from_port                 = 0
  to_port                   = 65535
  protocol                  = -1
  security_group_id         = module.msk-sg-replicator[each.key].sg_ids[format("msk-replicator-%s", each.key)]  

  source_security_group_id  = data.aws_msk_cluster.msk-cluster-for-replicator[
    format(
      "%s-%s-%s",
      each.value["msk_cluster_name"],
      each.value["replicator_name"],
      each.value["amazon_msk_cluster"]["msk_cluster_name"]
    )
  ].tags["sg_id"]
  
}



#
# Deploying Rule thatg allow Egress from MSK Replicator to MSK Brokers
#
resource "aws_security_group_rule" "sgrule-msk-replicator-allowing-egress-to-sg-msk-broker-remoteregion" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  type                      = "egress"
  from_port                 = 0
  to_port                   = 65535
  protocol                  = -1
  security_group_id         = aws_security_group.msk-sg-replicator-remoteregion[
    format("%s", each.key)
  ].id

  source_security_group_id  = data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
    format(
      "%s-%s-%s",
      each.value["msk_cluster_name"],
      each.value["replicator_name"],
      each.value["amazon_msk_cluster"]["msk_cluster_name"]
    )
  ].tags["sg_id"]
  
  provider = aws.dr
}

#
# Deploying Rule thatg allow Ingress from MSK Replicator to MSK Brokers
#
resource "aws_security_group_rule" "sgrule-msk-broker-allowing-ingress-from-sg-msk-replicator" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  )  if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name"     = k,
                      "replicator_name"      = x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  type                      = "ingress"
  from_port                 = 0
  to_port                   = 65535
  protocol                  = -1
  security_group_id         = data.aws_msk_cluster.msk-cluster-for-replicator[
    format(
      "%s-%s-%s",
      each.value["msk_cluster_name"],
      each.value["replicator_name"],
      coalesce(
        each.value["amazon_msk_cluster"]["msk_cluster_name"],
        each.value["amazon_msk_cluster"]["msk_cluster_arn"]
      )
    )
  ].tags["sg_id"]
  
  source_security_group_id  = module.msk-sg-replicator[
    each.key
  ].sg_ids[
    format("msk-replicator-%s", each.key)
  ] 
}

#
# Deploying Rule thatg allow Ingress from MSK Replicator to MSK Brokers
#
resource "aws_security_group_rule" "sgrule-msk-broker-allowing-ingress-from-sg-msk-replicator-remoteregion" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  )  if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name"     = k,
                      "replicator_name"      = x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  type                      = "ingress"
  from_port                 = 0
  to_port                   = 65535
  protocol                  = -1
  security_group_id         = data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
    format(
      "%s-%s-%s",
      each.value["msk_cluster_name"],
      each.value["replicator_name"],
      coalesce(
        each.value["amazon_msk_cluster"]["msk_cluster_name"],
        each.value["amazon_msk_cluster"]["msk_cluster_arn"]
      )
    )
  ].tags["sg_id"]
  
  source_security_group_id  = aws_security_group.msk-sg-replicator-remoteregion[
    each.key
  ].id

  provider = aws.dr
}









##
## Deploy MSK Replicator
##
resource "aws_msk_replicator" "msk-replicator" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ for x in coalesce(
            try(
              v["cluster"]["replicator"],
              null
            ),
            []
          ):
            format("%s-%s-%s-%s",
              k,
              x["replicator_name"],
              md5(
                coalesce(
                  x["replication_info_list"]["source_kafka_cluster_name"], x["replication_info_list"]["source_kafka_cluster_arn"]
                )
              ),
              md5(
                coalesce(
                  x["replication_info_list"]["target_kafka_cluster_name"], x["replication_info_list"]["target_kafka_cluster_arn"]
                )
              )
            )
          ] if (
            (
              try(v["cluster"]["create"], false) == true
            ) &&
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
      for k,v in var.msk_config:
        [ for x in coalesce(
          try(
            v["cluster"]["replicator"],
            null
          ),
          []
        ):
          merge(
            x,
            {"msk_cluster_name": k}
          )
        ] if (
          (
            try(v["cluster"]["create"], false) == true
          ) &&
          (
            v["cluster"]["replicator"] != null
          )
        )
      ]
    )
  )

  
  description                = coalesce(
    each.value["description"],
    format("MSK Replicator %s", each.value["replicator_name"])
  )

  dynamic "kafka_cluster" {

    for_each = coalesce(
      each.value["kafka_cluster"],
      []
    )
    
    content {

      amazon_msk_cluster {
        msk_cluster_arn = coalesce(
          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"],
          try(  
            data.aws_msk_cluster.msk-cluster-for-replicator[
              format(
                "%s-%s-%s",
                each.value["msk_cluster_name"],
                each.value["replicator_name"],
                kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"]
              )
            ].arn,
            data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
              format(
                "%s-%s-%s",
                each.value["msk_cluster_name"],
                each.value["replicator_name"],
                kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"]
              )
            ].arn            
          )
        )
      }
  
      vpc_config {
        subnet_ids = kafka_cluster.value["amazon_msk_cluster"]["region"] == null ? coalescelist(
          try(
            tolist(
              kafka_cluster.value["vpc_config"]["subnet_ids"]
            ),
            []
          ),  
          data.aws_subnets.msk-replicator-subnets[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              md5(
                coalesce(
                  kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
                  kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
                )
              )
            )
          ].ids,
          data.aws_subnets.default-msk-replicator-subnets[
            format(
              "%s-%s-%s",
              each.value["msk_cluster_name"],
              each.value["replicator_name"],
              md5(
                coalesce(
                  kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
                  kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
                )
              )
            )
          ].ids
        ) : data.aws_subnets.default-msk-replicator-subnets-remoteregion[
          "sales-teste-78c4a36897971802b3addf0780f03b2c"
        ].ids
        
        
        #data.aws_subnets.msk-replicator-subnets-remoteregion[
        #  format(
        #    "%s-%s-%s",
        #    each.value["msk_cluster_name"],
        #    each.value["replicator_name"],
        #    md5(
        #      coalesce(
        #        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
        #        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
        #      )
        #    )
        #  )
        #].ids
        
        
        #coalescelist(
        #  #try(
        #  #  tolist(
        #  #    kafka_cluster.value["vpc_config"]["subnet_ids"]
        #  #  ),
        #  #  []
        #  #),
        #  data.aws_subnets.msk-replicator-subnets-remoteregion[
        #    format(
        #      "%s-%s-%s",
        #      each.value["msk_cluster_name"],
        #      each.value["replicator_name"],
        #      md5(
        #        coalesce(
        #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
        #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
        #        )
        #      )
        #    )
        #  ].ids,
        #  data.aws_subnets.default-msk-replicator-subnets-remoteregion[
        #    format(
        #      "%s-%s-%s",
        #      each.value["msk_cluster_name"],
        #      each.value["replicator_name"],
        #      md5(
        #        coalesce(
        #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
        #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
        #        )
        #      )
        #    )
        #  ].ids
        #)

        security_groups_ids = coalescelist(
          try(
            kafka_cluster.value["vpc_config"]["security_groups"],
            []
          ),
          tolist(
            [
              try(
                aws_security_group.msk-sg-replicator-remoteregion[
                  format("%s-%s-%s",
                    each.value["msk_cluster_name"],
                    each.value["replicator_name"],
                    md5(
                      coalesce(
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
                      ) 
                    )
                  )
                ].id,
                module.msk-sg-replicator[
                  #
                  # Format the string to match SG TF Id to the MSK Replicator SG Module
                  #
                  format(
                    "%s-%s-%s",
                    each.value["msk_cluster_name"],
                    each.value["replicator_name"],
                    md5(
                      coalesce(
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
                      ) 
                    )
                  )
                ].sg_ids[
                  #
                  # Format the string to match the name of the Replicator SG inside the MSK Replicator SG Module
                  #
                  format("msk-replicator-%s-%s-%s",
                    each.value["msk_cluster_name"],
                    each.value["replicator_name"],
                    md5(
                      coalesce(
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
                        kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
                      ) 
                    )
                  )
                ]                
              )


              #try(
              #  module.msk-sg-replicator[
              #    #
              #    # Format the string to match SG TF Id to the MSK Replicator SG Module
              #    #
              #    format(
              #      "%s-%s-%s",
              #      each.value["msk_cluster_name"],
              #      each.value["replicator_name"],
              #      md5(
              #        coalesce(
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
              #        ) 
              #      )
              #    )
              #  ].sg_ids[
              #    #
              #    # Format the string to match the name of the Replicator SG inside the MSK Replicator SG Module
              #    #
              #    format("msk-replicator-%s-%s-%s",
              #      each.value["msk_cluster_name"],
              #      each.value["replicator_name"],
              #      md5(
              #        coalesce(
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
              #        ) 
              #      )
              #    )
              #  ],
              #  aws_security_group.msk-sg-replicator-remoteregion[
              #    format("msk-replicator-%s-%s-%s",
              #      each.value["msk_cluster_name"],
              #      each.value["replicator_name"],
              #      md5(
              #        coalesce(
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_name"],
              #          kafka_cluster.value["amazon_msk_cluster"]["msk_cluster_arn"]
              #        ) 
              #      )
              #    )
              #  ].id
              #)
            ]
          )
        )
      }
    }
  }

  replication_info_list {
    
    source_kafka_cluster_arn = try(
        data.aws_msk_cluster.msk-cluster-for-replicator[
          format(
            "%s-%s-%s",
            each.value["msk_cluster_name"],
            each.value["replicator_name"],
            each.value["replication_info_list"]["source_kafka_cluster_name"]
          )
        ].arn,
        data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
          format(
            "%s-%s-%s",
            each.value["msk_cluster_name"],
            each.value["replicator_name"],
            each.value["replication_info_list"]["source_kafka_cluster_name"]
          )
        ].arn,
      each.value["replication_info_list"]["source_kafka_cluster_arn"]
    )
    
    target_kafka_cluster_arn = try(
      data.aws_msk_cluster.msk-cluster-for-replicator[
        format(
          "%s-%s-%s",
          each.value["msk_cluster_name"],
          each.value["replicator_name"],
          each.value["replication_info_list"]["target_kafka_cluster_name"]
        )
      ].arn,
      data.aws_msk_cluster.msk-cluster-for-replicator-remoteregion[
        format(
          "%s-%s-%s",
          each.value["msk_cluster_name"],
          each.value["replicator_name"],
          each.value["replication_info_list"]["target_kafka_cluster_name"]
        )
      ].arn,
      each.value["replication_info_list"]["target_kafka_cluster_arn"]
    )
    
    target_compression_type  = each.value["replication_info_list"]["target_compression_type"]


    topic_replication {
      topics_to_replicate                  = each.value["replication_info_list"]["topic_replication"]["topics_to_replicate"]
      topics_to_exclude                    = each.value["replication_info_list"]["topic_replication"]["topics_to_exclude"]
      detect_and_copy_new_topics           = each.value["replication_info_list"]["topic_replication"]["detect_and_copy_new_topics"]
      copy_access_control_lists_for_topics = each.value["replication_info_list"]["topic_replication"]["copy_access_control_lists_for_topics"]
      copy_topic_configurations            = each.value["replication_info_list"]["topic_replication"]["copy_topic_configurations"]
    }

    consumer_group_replication {
      consumer_groups_to_replicate        = each.value["replication_info_list"]["consumer_group_replication"]["consumer_groups_to_replicate"]
      consumer_groups_to_exclude          = each.value["replication_info_list"]["consumer_group_replication"]["consumer_groups_to_exclude"]
      detect_and_copy_new_consumer_groups = each.value["replication_info_list"]["consumer_group_replication"]["detect_and_copy_new_consumer_groups"]
      synchronise_consumer_group_offsets  = each.value["replication_info_list"]["consumer_group_replication"]["synchronise_consumer_group_offsets"]
    }
  }

  replicator_name            = each.value["replicator_name"]
  
  service_execution_role_arn =     aws_iam_role.msk-replicator-iamrole[each.key].arn

#coalesce(
#    each.value["service_execution_role_arn"],
#    aws_iam_role.msk-replicator-iamrole[each.key].arn
#  )
}



output "name" {
  value =  zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  format("%s-%s-%s",
                    k,
                    x["replicator_name"],
                    md5(
                      coalesce(
                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
                      )
                    )
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] == null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )
  #zipmap(
  #  flatten(
  #    [
  #    for k,v in var.msk_config:
  #      [ for x in coalesce(
  #        try(
  #          v["cluster"]["replicator"],
  #          null
  #        ),
  #        []
  #      ):
  #        [
  #          for y in coalesce(x["kafka_cluster"], []):
  #            format("%s-%s-%s",
  #              k,
  #              x["replicator_name"],
  #              y["amazon_msk_cluster"]["msk_cluster_name"]
  #            ) if (
  #              (
  #                y["amazon_msk_cluster"]["msk_cluster_name"] != null
  #              )
  #            )
  #        ]
  #      ] if (
  #        (
  #          try(v["cluster"]["create"], false) == true
  #        ) &&
  #        (
  #          v["cluster"]["replicator"] != null
  #        )
  #      )
  #    ]
  #  ),
  #  flatten(
  #    [
  #    for k,v in var.msk_config:
  #      [ for x in coalesce(
  #        try(
  #          v["cluster"]["replicator"],
  #          null
  #        ),
  #        []
  #      ):
  #        [
  #          for y in coalesce(x["kafka_cluster"], []):
  #            y if (
  #              (
  #                 y["amazon_msk_cluster"]["msk_cluster_name"] != null
  #              )
  #            )
  #        ]
  #      ] if (
  #        (
  #          try(v["cluster"]["create"], false) == true
  #        ) &&
  #        (
  #          v["cluster"]["replicator"] != null
  #        )
  #      )
  #    ]
  #  )
  #)
  
#  value = zipmap(
#    flatten(
#      [
#        for k,v in var.msk_config:
#          [ 
#            for x in coalesce(
#              try(
#                v["cluster"]["replicator"],
#                null
#              ),
#              []
#            ):
#              [
#                for y in x["kafka_cluster"]:
#                  format("%s-%s-%s",
#                    k,
#                    x["replicator_name"],
#                    md5(
#                      coalesce(
#                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
#                      )
#                    )
#                  )
#              ]
#          ] if (
#            (
#              v["cluster"]["replicator"] != null
#            )
#          )
#      ]
#    ),
#    flatten(
#      [
#        for k,v in var.msk_config:
#          [ 
#            for x in coalesce(
#              try(
#                v["cluster"]["replicator"],
#                null
#              ),
#              []
#            ):
#              [
#                for y in x["kafka_cluster"]:
#                  merge(
#                    y,
#                    {
#                      "msk_cluster_name": k,
#                      "replicator_name": x["replicator_name"]
#                    }
#                  )
#              ]
#          ] if (
#            (
#              v["cluster"]["replicator"] != null
#            )
#          )
#      ]
#    )
#  )
}



























#
# Retrieving VPC IDs from 
#
data "aws_vpcs" "default-msk-vpc-remoteregion" {
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:    
                  coalesce(
                    y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]        
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  dynamic "filter" {  
    for_each = coalesce(
      try(
        each.value["common"]["vpc_config"]["vpc_filter"],
        null
      ),
      [
        {
          name = "tag:ops.team/msk/replicator/default"
          values = toset([true]) 
        }
      ]
    )
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }

  lifecycle {

   #
   # It is important notice that the true return match with the Error condition output.
   # Each EKS should have just ONE VPC with a tag matching.
   #
    postcondition {
      condition = (
        length(
          flatten(
            [
              for k, v in self:
                try(
                  v["ids"],
                  []
                )
            ] 
          )
        ) > 1 ?
          false
        : 
          true
      )
      error_message = "There are more than one VPC with the same tag. It is not permitted."
    }
  }

  provider = aws.dr
}


#
# Retrieving VPC IDs from 
#
data "aws_vpcs" "msk-vpc-remoteregion" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:    
                  coalesce(
                    y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]        
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [ 
            for x in coalesce(
              try(
                v["cluster"]["replicator"],
                null
              ),
              []
            ):
              [
                for y in x["kafka_cluster"]:
                  merge(
                    y,
                    {
                      "msk_cluster_name": k,
                      "replicator_name": x["replicator_name"]
                    }
                  ) if (
                    (
                      y["amazon_msk_cluster"]["region"] != null
                    )
                  )
              ]
          ] if (
            (
              v["cluster"]["replicator"] != null
            )
          )
      ]
    )
  )

  dynamic "filter" {  
    for_each = coalesce(
      try(
        each.value["vpc_config"]["vpc_filter"],
        null
      ),
      [
        {
          name = format(
            "tag:ops.team/msk/replicator/%s", 
            coalesce(
              try(
                each.value["amazon_msk_cluster"]["msk_cluster_name"],
                null
              ),
              each.key
            )
          )
          values = toset(
            [
              true
            ]
          ) 
        }
      ]
    )
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }

  lifecycle {

   #
   # It is important notice that the true return match with the Error condition output.
   # Each EKS should have just ONE VPC with a tag matching.
   #
    postcondition {
      condition = (
        length(
          flatten(
            [
              for k, v in self:
                try(
                  v["ids"],
                  []
                )
            ] 
          )
        ) > 1 ?
          false
        : 
          true
      )
      error_message = "There are more than one VPC with the same tag. It is not permitted."
    }
  }

  provider = aws.dr
}