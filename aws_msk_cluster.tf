#
# Deploy MSK Cluster
#
resource "aws_msk_cluster" "msk-cluster" {
  for_each = { for k,v in var.msk_config:
    k => v if (
      (
        try(v["cluster"]["create"], false) == true
      ) && (
        try(v["cluster"]["mode"], "provisioned") == "provisioned"
      )
    )
  }

  client_authentication {
    dynamic "sasl" {
      for_each = coalesce([each.value["cluster"]["client_authentication"]["sasl"]], [])
      content {
        iam   = sasl.value["iam"]
        scram = sasl.value["scram"]
      }
    }
    dynamic "tls" {
      for_each = each.value["cluster"]["client_authentication"]["tls"] != null ? [each.value["cluster"]["client_authentication"]["tls"]] : []
      content {
        certificate_authority_arns = tls.value["certificate_authority_arns"]
      }
    }
    unauthenticated = each.value["cluster"]["client_authentication"]["unauthenticated"]
  }


  dynamic "client_authentication" {
    for_each = try(
      coalesce(
        each.value["cluster"]["client_authentication"],
        {}
      ),
      {}
    )

    content {
      sasl {
        scram = client_authentication.value["sasl"]["scram"]
        iam   = client_authentication.value["sasl"]["iam"]
      }
      ##dynamic "tls" {
      ##  for_each = coalesce(client_authentication.value["tls"], {})
      ##  content {
      ##    certificate_authority_arns = tls.value["certificate_authority_arns"]
      ##  }
      ##}
      unauthenticated = client_authentication.value["unauthenticated"]
    }
  }

  cluster_name  = coalesce(
    each.value["cluster"]["name"],
    each.key
  )

  dynamic "configuration_info" {
    for_each = each.value["cluster"]["configuration_info"] != null ? toset(
      [
        each.value["cluster"]["configuration_info"]
      ]
    ) : []
    
    content {
      arn      = coalesce(configuration_info.value["arn"], aws_msk_configuration.msk-config[each.key].arn)
      revision = configuration_info.value["revision"]
    }
  }

  dynamic "encryption_info" {
    for_each = each.value["cluster"]["encryption_info"] != null ? toset(
      [
        each.value["cluster"]["encryption_info"]
      ]
    ) : []
    content {
      encryption_in_transit {
        client_broker = try(encryption_info.value["encryption_in_transit"]["client_broker"], null)
        in_cluster    = try(encryption_info.value["encryption_in_transit"]["in_cluster"], null)
      }
      encryption_at_rest_kms_key_arn = coalesce(encryption_info.value["encryption_at_rest_kms_key_arn"], module.kms.kms_key[format("msk-%s", each.key)].arn)
    }
  }

  enhanced_monitoring    =  each.value["cluster"]["enhanced_monitoring"]

  kafka_version          = each.value["cluster"]["kafka_version"]
  number_of_broker_nodes = each.value["cluster"]["number_of_broker_nodes"] 
  #* length(each.value["cluster"]["broker_node_group_info"]["client_subnets"])

  dynamic "open_monitoring" {
    for_each = try(coalesce(each.value["cluster"]["open_monitoring"], {}), {})
    content {
      prometheus {

        dynamic "jmx_exporter" {
          for_each = open_monitoring.value["jmx_exporter"]
          content {
            enabled_in_broker = jmx_exporter.value
          }
        }
        dynamic "node_exporter" {
          for_each = open_monitoring.value["node_exporter"]
          content {
            enabled_in_broker = node_exporter.value
          }
        }

      }
    }
  }

  dynamic "logging_info" {
    for_each = coalesce(each.value["cluster"]["logging_info"], {})
    content {
      broker_logs {

        # CloudWatch Logs
        cloudwatch_logs {
          enabled   = coalesce(logging_info.value["cloudwatch_logs"]["enabled"], false)
          log_group = lookup(logging_info.value["cloudwatch_logs"], "log_group", null)
        }

        # Firehose
        firehose {
          enabled         = coalesce(logging_info.value["firehose"]["enabled"], false)
          delivery_stream = lookup(logging_info.value["firehose"], "delivery_stream", null)
        }

        # S3
        s3 {
          enabled = coalesce(logging_info.value["s3"]["enabled"], false)
          bucket  = lookup(logging_info.value["s3"], "bucket", null)
          prefix  = lookup(logging_info.value["s3"], "prefix", null)
        }
      }
    }
  }

  dynamic "broker_node_group_info" {
    for_each = try(
      coalesce(
        [
          each.value["cluster"]["broker_node_group_info"]
        ],
        []
      ),
      []
    )

    #############
    content {
      az_distribution = broker_node_group_info.value["az_distribution"]

      dynamic "connectivity_info" {
        for_each = try(coalesce(broker_node_group_info.value["connectivity_info"], {}), {})

        content {
          dynamic "vpc_connectivity" {
            for_each = try(coalesce(connectivity_info.value["vpc_connectivity"], {}), {})
            content {
              dynamic "client_authentication" {
                for_each = try(coalesce(vpc_connectivity.value["client_authentication"], {}), {})
        
                content {
                  sasl {
                    scram = client_authentication.value["sasl"]["scram"]
                    iam   = client_authentication.value["sasl"]["iam"]
                  }
                  
                  #
                  # Has the try cause if the parent variable client_authentication be defined 
                  # with no tls parameter we must ensure the parameter to exists.
                  #
                  tls = try(
                    client_authentication.value["tls"],
                    true
                  )
                }
              }
            }
          }
        
          dynamic "public_access" {
            for_each = try(coalesce(broker_node_group_info.value["public_access"], {}), {})
            content {
              type = public_access.value["type"]
            }
          }
        
        }
      }

      client_subnets = coalescelist(
        tolist(
          broker_node_group_info.value["client_subnets"]
        ),
        data.aws_subnets.msk-subnets[each.key].ids,
        data.aws_subnets.default-msk-subnets[each.key].ids
      )

      instance_type = broker_node_group_info.value["instance_type"]

      security_groups = coalesce(
        broker_node_group_info.value["security_groups"],
        toset(
          [
            module.msk-sg[each.key].sg_ids[format("msk-%s", each.key)]
          ]
        )
      )

      dynamic "storage_info" {
        for_each = try(coalesce(broker_node_group_info.value["storage_info"], {}), {})

        content {
          ebs_storage_info {

            dynamic "provisioned_throughput" {
              for_each = try(coalesce(broker_node_group_info.value["ebs_storage_info"]["provisioned_throughput"],{}),{})
              content {
                enabled           = provisioned_throughput.value["enabled"]
                volume_throughput = provisioned_throughput.value["volume_throughput"]
              } 
            }

            volume_size = storage_info.value["volume_size"]
          }
        }
      }
    }   
  }

  tags                   = merge(
    tomap(
      {
        "sg_id" = module.msk-sg[each.key].sg_ids[format("msk-%s", each.key)]
      }
    ),
    each.value["cluster"]["tags"]
  )

}

#
# Deploy MSK Serverless Cluster
#
resource "aws_msk_serverless_cluster" "msk-cluster"  {
  
  for_each = { for k,v in var.msk_config:
    k => v if (
      (
        try(v["cluster"]["create"], false) == true
      ) && (
        try(v["cluster"]["mode"], "provisioned") == "serverless"
      )
    )
  }


  client_authentication {
    dynamic "sasl" {
      for_each = coalesce(
        [
          each.value["cluster"]["client_authentication"]["sasl"]
        ],
        []
      )
      content {
        dynamic "iam" {
          for_each = try(
            [
              tomap(
                {
                  "iam" = sasl.value["iam"]
                }
              )
            ],
            []
          )
          content {
            enabled = iam.value["iam"]
          }  
        }
      }
    }
  }

  cluster_name         = coalesce(
    each.value["cluster"]["name"],
    each.key
  )

  tags                 = each.value["cluster"]["tags"]

  vpc_config {
    subnet_ids         = coalescelist(
      data.aws_subnets.msk-subnets[each.key].ids,
      data.aws_subnets.default-msk-subnets[each.key].ids
    )

    security_group_ids = coalesce(
      try(
        each.value["cluster"]["broker_node_group_info"]["security_groups"],
        null
      ),
      toset(
        [
          module.msk-sg[each.key].sg_ids[format("msk-%s", each.key)]
        ]
      )
    )
  }
}
#
#output "name" {
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
#                      coalesce(
#                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
#                      )
#                  )
#                
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
#                  format("%s-%s-%s",
#                    k,
#                    x["replicator_name"],
#                    
#                      coalesce(
#                        y["amazon_msk_cluster"]["msk_cluster_name"], y["amazon_msk_cluster"]["msk_cluster_arn"]
#                      )
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
#}