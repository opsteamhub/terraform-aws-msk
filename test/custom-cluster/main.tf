locals {
  cluster_name = "custom-cluster"
  number_of_broker_nodes = 3
  vpc_id = "vpc-1234"
}

module "msk_cluster" {
  source = "../.."
  msk_config = {
    "${local.cluster_name}" = {
      common = {
        vpc_config = {
          create_security_group = true
          vpc_id = local.vpc_id
          security_group_rules = {
            name        = local.cluster_name
            description = "Security group for MSK"
            ingress = [
              {
                description = "Allowed MSK tls_port Port"
                from_port   = 9094
                to_port     = 9094
                protocol    = "tcp"
                cidr_blocks = ["10.0.0.0/16"]
              }
            ]

            egress = [
              {
                description      = "Allow all outbound traffic for MSK"
                from_port        = 9094
                to_port          = 9094
                protocol         = "tcp"
                cidr_blocks      = ["10.0.0.0/16"]
                #ipv6_cidr_blocks = ["::/0"]
              }
            ]
          }
        }
      }
      cluster = {
        cluster_identifier = local.cluster_name
        kafka_version      = "3.5.1"
        mode               = "provisioned"
        port               = 9094
        create             = true
        client_authentication = {
          sasl = {
            iam   = true
            scram = false
          },
          unauthenticated = true
        }
        enhanced_monitoring    = "DEFAULT"
        number_of_broker_nodes = local.number_of_broker_nodes

        broker_node_group_info = {
          instance_type = "kafka.m5.large"
          connectivity_info = {
            vpc_connectivity = {
              client_authentication = {
                sasl = {
                  iam   = true
                  scram = false
                },
                unauthenticated = true
              }
            }
          }
          storage_info = {
            ebs_storage_info = {
              volume_size = 500

              provisioned_throughput = {
                enabled           = false
                volume_throughput = 300
              }
            }
          }
        }

        msk_configuration = <<PROPERTIES
        auto.create.topics.enable = true
delete.topic.enable = true
default.replication.factor = 3
message.max.bytes=10000000
        PROPERTIES

        configuration_info = {
          revision = 1
        }

        encryption_info = {
          encryption_in_transit = {
            client_broker = "TLS_PLAINTEXT"
          }
        }

        tags = {
          environment = "dev"
          ProvisionedBy = "Terraform"
          service = local.cluster_name
        }

        logging_info = {
          broker_logs = {
            cloudwatch_logs = {
              enabled = true
              log_group = "my-logs"
            }
            firehose = {
              enabled = false
            }
            s3 = {
              enabled = false
            }
          }
        }

        scram_secret = [
          {
            create = false
          }
        ]

        open_monitoring = {
          prometheus = {
            jmx_exporter = {
              enabled_in_broker = false
            }
            node_exporter = {
              enabled_in_broker = false
            }
          }
        }
      }
    }
  }
}