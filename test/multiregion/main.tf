

module "dr_region" {
  source = "../../../terraform-aws-dr-region"
  dr_region_config = {
    enforced_dr_region = "us-east-2"
  }
}


module "msk_main_region" {
  source = "../.."
  disaster_recovery_region = module.dr_region.dr_region
  msk_config = {
    "sales" = {
      "cluster" = {
        configuration_info = {
          arn      = "arn:aws:kafka:us-east-1:288109893636:configuration/sales/c6a68af1-8139-4cef-83cd-3d34aa7440c2-22"
          revision = "2"
        }
        #broker_node_group_info = {
        #  connectivity_info = {
        #    vpc_connectivity = {
        #      client_authentication = {
        #        sasl = {
        #          scram = false
        #        }
        #      }
        #    }
        #  }
        #}
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
                  msk_cluster_name = "sales"
                }
                #vpc_config = {
                #  subnet_ids          = [
                #    "subnet-098c9b31dccd66c4b",
                #    "subnet-051d585c3a58c93bc",
                #    "subnet-087a144f11a0622bc",
                #  ]
                # } 
              },
              {
                amazon_msk_cluster = {
                  msk_cluster_name = "sales-dr"
                  region           = module.dr_region.dr_region
                }
                #vpc_config = {
                #  subnet_ids          = [
                #    "subnet-098c9b31dccd66c4b",
                #    "subnet-051d585c3a58c93bc",
                #    "subnet-087a144f11a0622bc",
                #  ]
                #}
              }             
            ]
            replicator_name = "teste"
            replication_info_list = {
              source_kafka_cluster_name = "sales-dr"
              target_kafka_cluster_name = "sales"
            }
          },
        ]
      }
    }
  }
}

output "name" {
  value = ""# module.msk_main_region.name
}