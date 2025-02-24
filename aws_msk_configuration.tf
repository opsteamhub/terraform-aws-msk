#
# Deploy AWS MSK Configuration
#
resource "aws_msk_configuration" "msk-config" {
  for_each = { for k,v in var.msk_config:
    k => v if (
      try(v["cluster"]["create"], false) == true
    )
  }

  kafka_versions = toset(
    [
      each.value["cluster"]["kafka_version"]
    ]
  )

  name              = each.key
  server_properties = each.value["cluster"]["msk_configuration"]
}