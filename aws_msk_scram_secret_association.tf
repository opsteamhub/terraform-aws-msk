#
# Define a random Username to be used in SCRAM Screts
#
resource "random_uuid" "msk-scram-username" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )
}

#
# Define a random Passoword to be used in SCRAM Screts
#
resource "random_password" "msk-scram-password" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )

  length           = 20
  special          = true
}

#
# Deploy AWS Scret to be Associate to MSK cluster by SCRAM
#
resource "aws_secretsmanager_secret" "msk-secretsmanager-secret" {
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                    "kms_master_key_id" = v["cluster"]["kms_master_key_id"]
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )
  
  name_prefix = format(
    "AmazonMSK_%s",
    each.value["cluster_name"]
  )
  kms_key_id = coalesce(
    each.value["kms_master_key_id"],
    module.kms.kms_key[format("msk-%s", each.value["cluster_name"])].arn,
  )
}

#
# Deploy a AWS Secret Versions 
#
resource "aws_secretsmanager_secret_version" "msk-secretsmanager-secret" {
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )

  secret_id     = aws_secretsmanager_secret.msk-secretsmanager-secret[each.key].id
  secret_string = (each.value["secret_string"] != null) ? jsonencode(
    each.value["secret_string"]
  ) : jsonencode(
      tomap(
      {
        username = random_uuid.msk-scram-username[each.key].result
        password = random_password.msk-scram-password[each.key].result
      }
    )
  )
}

#
# Define Resourc-Policy to be attached to the AWS Secret
#
data "aws_iam_policy_document" "msk-secretsmanager-secret-policy" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )

  statement {
    sid    = "AWSKafkaResourcePolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }

    actions   = ["secretsmanager:getSecretValue"]
    resources = [aws_secretsmanager_secret.msk-secretsmanager-secret[each.key].arn]
  }
}

#
# Deploy Resource-Policy in AWS Secret
#
resource "aws_secretsmanager_secret_policy" "msk-secretsmanager-secret-policy" {
  for_each = zipmap(
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              sha256(
                join("",
                  compact(
                    concat(
                      flatten(
                        values(
                          merge(
                            tomap(
                              {
                                "cluster_name" = coalesce(
                                  try(v["cluster"]["name"], null),
                                  k
                                )
                              }
                            ),
                            x
                          )
                        )
                      )
                    )
                  )
                )
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.msk_config:
          [
            for x in coalesce(
              try(
                v["cluster"]["scram_secret"],
                null
              ),
              []
            ):
              merge(
                tomap(
                  {
                    "cluster_name" = coalesce(
                      v["cluster"]["name"],
                      k
                    )
                  }
                ),
                x
              ) if (
                (
                  try(x["create"], false) == true
                )
              )
          ]
      ]
    )
  )

  secret_arn = aws_secretsmanager_secret.msk-secretsmanager-secret[each.key].arn
  policy     = data.aws_iam_policy_document.msk-secretsmanager-secret-policy[each.key].json
}


#
# Associate AWS Scret with the MSK Cluster
#
#resource "aws_msk_scram_secret_association" "msk-scram-secret-association" {
#
#  for_each = {
#    for k,v in var.msk_config:
#      k => [ for x in coalesce(
#        try(
#          v["cluster"]["scram_secret"],
#          null
#        ),
#        []
#      ):
#        sha256(
#          join("",
#            compact(
#              concat(
#                flatten(
#                  values(
#                    merge(
#                      tomap(
#                        {
#                          "cluster_name" = coalesce(
#                            try(v["cluster"]["name"], null),
#                            k
#                          )
#                        }
#                      ),
#                      x
#                    )
#                  )
#                )
#              )
#            )
#          )
#        ) if (
#          (
#            try(x["create"], false) == true
#          )
#        )
#      ]
#  }
#
#
#  cluster_arn     =  try(
#    aws_msk_cluster.msk-cluster[each.key].arn,  
#    each.value["target_cluster_arn"]
#  )
#
#  secret_arn_list = [ for x in each.value:
#    aws_secretsmanager_secret.msk-secretsmanager-secret[x].arn
#  ]
#}