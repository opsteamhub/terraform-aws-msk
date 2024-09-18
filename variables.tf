variable "disaster_recovery_region" {
  description = "Configure one Region to be the Remote Zone to replicate MSK using Replicator."
  type        = string
  default     = null
}

variable "msk_config" {
  description = "value"
  type = map(
    object(
      {

        common = optional(
          object(
            {      
              tags                    = optional(map(string))
              vpc_config              = optional(
                object(
                  {
                    create_security_group      = optional(bool, true)
                    security_group_rules = optional( # Security group configuration for the VPC                  
                      object(
                        {
                          egress = optional(             # Egress rule configuration for the security group
                            list(
                              object(
                                {
                                  description               = optional(string)      # Description of the egress rule
                                  from_port                 = optional(string, 0)      # Starting port range for the egress rule
                                  to_port                   = optional(string, 65535)      # Ending port range for the egress rule
                                  protocol                  = optional(string, "tcp")      # Protocol to use for the egress rule
                                  cidr_blocks               = optional(set(string), ["0.0.0.0/0"]) # List of CIDR blocks for the egress rule
                                  ipv6_cidr_blocks          = optional(set(string)) # List of IPv6 CIDR blocks for the egress rule
                                  prefix_list_ids           = optional(set(string)) # List of prefix list IDs for the egress rule
                                  source_security_group_id  = optional(string)      # Security group to associate with the egress rule
                                }
                              )
                            )
                          )
                          ingress = optional( # Ingress rule configuration for the security group
                            list(
                              object(
                                {
                                  description               = optional(string)      # Description of the ingress rule
                                  from_port                 = optional(string)      # Starting port range for the ingress rule
                                  to_port                   = optional(string)      # Ending port range for the ingress rule
                                  protocol                  = optional(string, "tcp")      # Protocol to use for the ingress rule
                                  cidr_blocks               = optional(set(string)) # List of CIDR blocks for the ingress rule
                                  ipv6_cidr_blocks          = optional(set(string)) # List of IPv6 CIDR blocks for the ingress rule
                                  prefix_list_ids           = optional(set(string)) # List of prefix list IDs for the ingress rule
                                  source_security_group_id  = optional(string)      # Security group to associate with the ingress rule
                                }
                              )
                            )
                          )
                          revoke_rules_on_delete = optional(bool, false)      # If 'true', will revoke all rules when the security group is deleted.  This is normally not needed, however certain AWS services such as Elastic Map Reduce may automatically add required rules to security groups used with the service, and those rules may contain a cyclic dependency that prevent the security groups from being destroyed without removing the dependency first. Default false.
                          tags                   = optional(map(string))      # Tags for the security group
                        }
                      ), {}
                    )
                    subnet_filter = optional(
                      set(
                        object(
                          {
                            name   = optional(string)
                            values = optional(set(string))
                          }
                        )
                      )
                    )
                    subnet_ids      = optional(set(string))
                    vpc_id          = optional(string)
                    vpc_filter = optional(
                      set(
                        object(
                          {
                            name   = optional(string)
                            values = optional(set(string))
                          }
                        )
                      )
                    )                
                  }
                ), {}
              )
            }
          ), {}
        )
        cluster = optional(
          object(
            {
              broker_node_group_info  = optional(
                object(
                  {
                    az_distribution      = optional(string, "DEFAULT")
                    client_subnets       = optional(set(string))
                    connectivity_info    = optional(
                      object(
                        {
                          public_access           = optional(
                            object(
                              {
                                type = optional(string, "DISABLED")
                              }
                            )
                          )
                          vpc_connectivity        = optional(
                            object(
                              {
                                client_authentication = optional(
                                  object(
                                    {
                                      sasl = optional(
                                        object(
                                          {
                                            iam   = optional(bool, true)
                                            scram = optional(bool, true)
                                          }
                                        )
                                      )
                                      tls  = optional(bool, true)
                                    }
                                  )
                                )
                              }
                            )
                          )
                        }
                      )
                    )
                    storage_info = optional(
                      object(
                        {
                          ebs_storage_info = optional(
                            object(
                              {
                                provisioned_throughput = optional(
                                  object(
                                    {
                                      enabled           = optional(bool, false)
                                      volume_throughput = optional(string, 250)
                                    }
                                  )
                                )
                                volume_size           = optional(string, 80)
                              }
                            )
                          )
                        }
                      )
                    )
                    instance_type         = optional(string, "kafka.m7g.large")
                    security_groups       = optional(set(string))  
                  }
                ), {}
              )
              client_authentication = optional(
                object(
                  {
                    sasl = optional(
                      object(
                        {
                          iam   = optional(bool, true)
                          scram = optional(bool, true)
                        }
                      ),
                      { }
                    )
                    tls  = optional(
                      object(
                        {
                          certificate_authority_arns = optional(string)
                        }
                      )
                    )
                    unauthenticated = optional(string)
                  }
                ),
                {}
              )
              cluster_name             = optional(string)
              configuration = optional(
                object(
                  {
                    description       = optional(string)
                    server_properties = optional(any)
                    kafka_versions    = optional(set(string))
                    name              = optional(string)
                  }
                )
              )
              configuration_info = optional(
                object(
                  {
                    arn      = optional(string)
                    revision = optional(string)
                  }
                )
              )
              create                   = optional(bool, true)
              enhanced_monitoring      = optional(string, "PER_BROKER") #"DEFAULT"|"PER_BROKER"|"PER_TOPIC_PER_BROKER"|"PER_TOPIC_PER_PARTITION",
              port                     = optional(string, 9094)
              encryption_info = optional(
                object(
                  {
                    encryption_in_transit          = optional(
                      object(
                        {
                          client_broker = optional(string, "TLS")
                          in_cluster    = optional(bool, true)
                        }
                      )
                    )
                    encryption_at_rest_kms_key_arn = optional(string)
                  }
                ),
                {}
              )
              logging_info             = optional(
                object(
                  {
                    broker_logs = optional(
                      object(
                        {
                          cloudwatch_logs = optional(
                            object(
                              {
                                enabled   = optional(bool, true)
                                log_group = optional(string)
                              }
                            )
                          )
                          firehose = optional(
                            object(
                              {
                                enabled         = optional(bool, true)
                                delivery_stream = optional(string)
                              }
                            )
                          )
                          s3 = optional(
                            object(
                              {
                                enabled = optional(bool, true)
                                bucket  = optional(string)
                                prefix  = optional(string)
                              }
                            )
                          )            
                        }          
                      )
                    )
                  }
                )
              )
              open_monitoring          = optional(
                object(
                  {
                    prometheus = object(
                      {
                        jmx_exporter  = optional(
                          object(
                            {
                              enabled_in_broker = optional(bool, true) 
                            }
                          )
                        )
                        node_exporter = optional(
                          object(
                            {
                              enabled_in_broker = optional(bool, true) 
                            }
                          )
                        )
                      }
                    )
                  }
                )
              )
              policy                   = optional(
                set(
                  object(
                    {
                      actions        = optional(set(string))
                      condition      = optional(
                        set(
                          object(    
                            {
                              test     = optional(string)
                              variable = optional(string)
                              values   = optional(set(string))
                            }
                          )
                        )
                      )
                      effect         = optional(string, "Deny")
                      not_actions    = optional(set(string))
                      not_principals = optional(
                        set(
                          object(
                            {  
                            identifiers = optional(set(string))
                            type        = optional(string)  
                            }
                          )
                        )
                      )
                      not_resources  = optional(set(string))
                      principals     = optional(
                        set(
                          object(
                            {  
                            identifiers = optional(set(string))
                            type        = optional(string)
                            }
                          )
                        )    
                      )
                      resources      = optional(set(string))
                      sid            = optional(string)
                    }
                  )
                )
              )
              kafka_version            = optional(string, "3.6.0")
              kms_master_key_id        = optional(string)
              mode                     = optional(string, "provisioned")
              name                     = optional(string)
              number_of_broker_nodes   = optional(string, 3)
              replicator = optional(
                set(
                  object(
                    {
                      description   = optional(string)
                      kafka_cluster = optional(
                        set(
                          object(
                            {
                              amazon_msk_cluster = optional(
                                object(
                                  {
                                    msk_cluster_arn  = optional(string)
                                    msk_cluster_name = optional(string)
                                    region           = optional(string)
                                  }
                                )
                              )
                              vpc_config         = optional(
                                object(
                                  {
                                    security_groups_ids = optional(set(string))
                                    subnet_filter       = optional(
                                      set(
                                        object(
                                          {
                                            name     = optional(string)
                                            values   = optional(set(string))
                                          }
                                        )
                                      )
                                    )
                                    subnet_ids       = optional(set(string))
                                    vpc_filter       = optional(
                                      set(
                                        object(
                                          {
                                            name   = optional(string)
                                            values = optional(set(string))
                                          }
                                        )
                                      )
                                    )
                                    vpc_id        = optional(string)
                                  }
                                )
                              )
                            }
                          )
                        )
                      )
                      replication_info_list      = optional(
                        object(
                          {
                            source_kafka_cluster_arn   = optional(string)
                            source_kafka_cluster_name  = optional(string)
                            target_kafka_cluster_arn   = optional(string)
                            target_kafka_cluster_name  = optional(string)
                            target_compression_type    = optional(string, "LZ4")
                            topic_replication          = optional(
                              object(
                                {
                                  topics_to_replicate                  = optional(set(string), [".*"])
                                  topics_to_exclude                    = optional(set(string)) 
                                  detect_and_copy_new_topics           = optional(bool, true) 
                                  copy_access_control_lists_for_topics = optional(bool, false)
                                  copy_topic_configurations            = optional(bool, true)
                                }
                              ),
                              { }
                            )
                            consumer_group_replication = optional(
                              object(
                                {
                                  consumer_groups_to_replicate        = optional(set(string), [".*"])
                                  consumer_groups_to_exclude          = optional(set(string))
                                  detect_and_copy_new_consumer_groups = optional(bool, true)
                                  synchronise_consumer_group_offsets  = optional(bool, true)
                                }
                              ),
                              { }
                            )
                          }
                        ),
                        { }
                      )
                      replicator_name                  = optional(string)
                      service_execution_role_arn       = optional(string)
                      vpc_config              = optional(
                        object(
                          {
                            subnet_filter = optional(
                              set(
                                object(
                                  {
                                    name   = optional(string)
                                    values = optional(set(string))
                                  }
                                )
                              )
                            )
                          }
                        )
                      )
                    }
                  )
                )
              )
              scram_secret             = optional(
                set(
                  object(
                    {
                      create        = optional(bool, true)
                      name          = optional(string)
                      secret_string = optional(string)
                    }
                  )
                ),
                [
                  {
                    
                  }
                ]
              ) 
              storage_mode             = optional(string, "LOCAL")
              tags                     = optional(map(string))
              vpc_connection           = optional(
                set(
                  object(
                    {
                      authentication      = optional(string, "SASL_IAM")
                      create              = optional(bool, true)
                      client_subnets      = optional(set(string), ["subnet-098c9b31dccd66c4b","subnet-051d585c3a58c93bc","subnet-087a144f11a0622bc",])
                      security_groups     = optional(set(string), ["sg-0a5ff729e982659d5"])
                      tags                = optional(map(string))
                      target_cluster_arn  = optional(string)
                      vpc_id              = optional(string, "vpc-06f56828a577ed1a7")
                    }
                  )
                ),
                 [{ }] ##
              )
            }
          ), { }
        )
      }
    )
  )
}