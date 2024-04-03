
module "msk_general_config" {
  source = "../.."
  msk_config = {
    "order" = {
      "cluster" = {
        #"broker_node_group_info" = { "az_distribution": "DEFAULT"}
        client_authentication = {
          sasl = {
            iam   = true
            scram = true
          }
        }
        replicator = [
          {
            kafka_cluster = [
              {
                amazon_msk_cluster = {
                  msk_cluster_name = "order"
                }
                vpc_config = {
                  subnet_ids          = [
                    "subnet-098c9b31dccd66c4b",
                    "subnet-051d585c3a58c93bc",
                    "subnet-087a144f11a0622bc",
                  ]
                  #security_groups_ids = ["sg-03fe852e6e577d5b0"]
                }
              },
              {
                amazon_msk_cluster = {
                  msk_cluster_name = "order2"
                }
                vpc_config = {
                  subnet_ids          = [
                    "subnet-098c9b31dccd66c4b",
                    "subnet-051d585c3a58c93bc",
                    "subnet-087a144f11a0622bc",
                  ]
                  #security_groups_ids = ["sg-0ea0bf7d57db38de3"]
                }
              }             
            ]
            replicator_name = "teste2"
            replication_info_list = {
              source_kafka_cluster_name = "order"
              target_kafka_cluster_name = "order2"
            }
          },


          #{
          #  kafka_cluster = [
          #    {
          #      amazon_msk_cluster = {
          #        msk_cluster_name = "order"
          #      }
          #    },
          #    {
          #      amazon_msk_cluster = {
          #        msk_cluster_name = "order2"
          #      }
          #    }             
          #  ]
          #  replicator_name = "teste2"
          #  replication_info_list = {
          #    source_kafka_cluster_arn = "order"
          #    target_kafka_cluster_arn = "order2"
          #  }
          #}
        ]
      }
    }
    "order2" = {
      "cluster" = {
        #"broker_node_group_info" = { "az_distribution": "DEFAULT"}
        client_authentication = {
          sasl = {
            iam   = true
            scram = true
          }
        }
      }
    }
    #"price" = {
    #  "cluster" = {
    #    "mode" = "serverless"
    #  }
    #}
  }
}

output "name" {
  value = module.msk_general_config.name
}