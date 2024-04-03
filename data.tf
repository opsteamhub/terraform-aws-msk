#
# Get Caller identity
#
data "aws_caller_identity" "session" {}

#
# Retrieve Session Main Region
#
data "aws_region" "session" {}

#
# Retrieve AWS Partition from this session
#
data "aws_partition" "session" {} 

#
# Retrieving VPC IDs from 
#
data "aws_vpcs" "default-msk-vpc" {
  for_each = var.msk_config

  dynamic "filter" {  
    for_each = coalesce(
      try(
        each.value["common"]["vpc_config"]["vpc_filter"],
        null
      ),
      [
        {
          name = "tag:ops.team/msk/cluster/default"
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
}


#
# Retrieving VPC IDs from 
#
data "aws_vpcs" "msk-vpc" {
  for_each = { for k,v in var.msk_config:
    k => v if (
      try(v["cluster"]["create"], false) == true
    )
  }

  dynamic "filter" {  
    for_each = coalesce(
      try(
        each.value["common"]["vpc_config"]["vpc_filter"],
        null
      ),
      [
        {
          name = format(
            "tag:ops.team/msk/cluster/%s", 
            coalesce(
              try(
                each.value["cluster"]["cluster_identifier"],
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
}


#
# Retrieving Subnets IDs from 
#
data "aws_subnets" "default-msk-subnets" {
  
  for_each = { for k,v in var.msk_config:
    k => v if (
      try(v["cluster"]["create"], false) == true
    )
  }

  filter {  
    name   = "vpc-id"
    values = coalesce(
      coalescelist(
        data.aws_vpcs.msk-vpc[each.key].ids,
        data.aws_vpcs.default-msk-vpc[each.key].ids,
      ),
      toset(
        [
          try(
            each.value["common"]["vpc_config"]["vpc_id"],
            null
          )
        ]
      )
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["common"]["vpc_config"]["subnet_filter"],
        null
      ),
      [
        {
          name   = "tag:ops.team/msk/cluster/default"
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
# Retrieving Subnets IDs from 
#
data "aws_subnets" "msk-subnets" {
  
  for_each = { for k,v in var.msk_config:
    k => v if (
      try(v["cluster"]["create"], false) == true
    )
  }

  filter {  
    name   = "vpc-id"
    values = coalesce(
      coalescelist(
        data.aws_vpcs.msk-vpc[each.key].ids,
        data.aws_vpcs.default-msk-vpc[each.key].ids,
      ),
      toset(
        [
          try(
            each.value["common"]["vpc_config"]["vpc_id"],
            null
          )
        ]
      )
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["common"]["vpc_config"]["subnet_filter"],
        null
      ),
      [
        {
          name   = format(
            "tag:ops.team/msk/cluster/%s",
            coalesce(
              try(
                each.value["cluster"]["cluster_identifier"],
                null
              ),
              each.key
            )
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
# TimeStamp used to deploy MSK Replicator Role
#
resource "time_static" "msk-timestamp" { 
  for_each = { for k, v in var.msk_config:
      k => v
    }
}
