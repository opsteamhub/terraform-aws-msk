#
# AWS MSK Security Groups
#
module "msk-sg" {

  for_each = zipmap(
    flatten(
      [
        for k, v in var.msk_config:
          [
            k
          ] if (
            (
              v["common"]["vpc_config"]["create_security_group"] == true
            )
            &&
            (
              try(v["cluster"]["create"], false) == true
            )
          )
      ]
    ),
    flatten(
      [
        for k, v in var.msk_config:
          [
            v            
          ] if ( 
            (
              v["common"]["vpc_config"]["create_security_group"] == true
            )
            &&
            (
              try( v["cluster"]["create"], false) == true
            )
          )
      ]
    )
  )

  source = "git@github.com:opsteamhub/terraform-aws-vpc.git"

  vpc_config = {
    vpc = {
      create = false
      vpc_id = coalesce(
        try(
          element(
            data.aws_vpcs.msk-vpc[each.key].ids,
            0
          ),
          null
        ),
        try(
          element(
            data.aws_vpcs.default-msk-vpc[each.key].ids,
            0
          ),
          null
        ),
        each.value["common"]["vpc_config"]["vpc_id"]
      )
    }
    security_groups = toset(  
      [
        merge(
          {
            name = format("msk-%s", each.key)
          },
          {
            "egress" = [
              for y in (
                  each.value["common"]["vpc_config"]["security_group_rules"]["egress"] != null
                ? 
                  each.value["common"]["vpc_config"]["security_group_rules"]["egress"]
                : 
                  []
              ):
                {
                  description               = y["description"]
                  from_port                 = y["from_port"]
                  to_port                   = y["to_port"]
                  protocol                  = y["protocol"]
                  cidr_blocks               = y["cidr_blocks"]
                  ipv6_cidr_blocks          = y["ipv6_cidr_blocks"]
                  prefix_list_ids           = y["prefix_list_ids"]
                  source_security_group_id  = y["source_security_group_id"] 
                }
            ]
          },
          {
            "ingress" = [
              for y in (
                  each.value["common"]["vpc_config"]["security_group_rules"]["ingress"] != null
                ? 
                  each.value["common"]["vpc_config"]["security_group_rules"]["ingress"]
                : []
              ):
                {
                  description               = y["description"]
                  from_port                 = coalesce(y["from_port"], each.value["cluster"]["port"])
                  to_port                   = coalesce(y["to_port"], each.value["cluster"]["port"])
                  protocol                  = y["protocol"]
                  cidr_blocks               = y["cidr_blocks"]
                  ipv6_cidr_blocks          = y["ipv6_cidr_blocks"]
                  prefix_list_ids           = y["prefix_list_ids"]
                  source_security_group_id  = y["source_security_group_id"] 
                }
            ]
          }
        )
      ]
    )
  }
}