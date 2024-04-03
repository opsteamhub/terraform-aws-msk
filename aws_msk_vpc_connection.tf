##
## Deploy MSK VPC Connection
## This resource is used to make the cluster available in other VPCs without 
## implement Peerring or TransitGWs. Pretty much the resource abstract the 
## PrivateLink implementation. Be happy forever!
##
#resource "aws_msk_vpc_connection" "msk-vpc-connection" {
#  for_each = zipmap(
#    flatten(
#      [
#        for k,v in var.msk_config:
#          [
#            for x in v["cluster"]["vpc_connection"]:
#              sha256(
#                join("",
#                  compact(
#                    concat(
#                      flatten(
#                        values(
#                          merge(
#                            tomap(
#                              {
#                                "cluster_name" = coalesce(
#                                  try(v["cluster"]["name"], null),
#                                  k
#                                )
#                              }
#                            ),
#                            { for w,z in x:
#                              w => z if ! (contains(["tags"], w))
#                            }
#                          )
#                        )
#                      )
#                    )
#                  )
#                )
#              ) if (
#                (
#                  try(x["create"], false) == true
#                ) && (
#                  try(v["cluster"]["mode"], "provisioned") == "provisioned"
#                )
#              )
#          ]
#      ]
#    ),
#    flatten(
#      [
#        for k,v in var.msk_config:
#          [
#            for x in coalesce(v["cluster"]["vpc_connection"], []):
#              merge(
#                tomap(
#                  {
#                    "cluster_name" = coalesce(
#                      v["cluster"]["name"],
#                      k
#                    )
#                  }
#                ),
#                x
#              ) if (
#                (
#                  try(x["create"], false) == true
#                ) && (
#                  try(v["cluster"]["mode"], "provisioned") == "provisioned"
#                )
#              )
#          ]
#      ]
#    )
#  )
# 
#  authentication     = each.value["authentication"]
#  target_cluster_arn = try(
#    aws_msk_cluster.msk-cluster[each.value["cluster_name"]].arn,
#    each.value["target_cluster_arn"]
#  )
#  vpc_id             = each.value["vpc_id"]
#  client_subnets     = each.value["client_subnets"]
#  security_groups    = each.value["security_groups"]
#  tags               = merge(
#    var.msk_config[each.value["cluster_name"]]["cluster"]["tags"],
#    each.value["tags"]
#  )
#}
#