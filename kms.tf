#
# Address the KMS deploy to be used by the AWS MSK
#
module "kms" {
  source   = "git@github.com:opsteamhub/terraform-aws-kms.git"
  kms_config = { 
    for k,v in var.msk_config:
      format("msk-%s", k) => { } if (
        try(v["cluster"]["create"], false) == true
      )
  }
}