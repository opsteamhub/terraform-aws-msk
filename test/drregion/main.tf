provider "aws" {
  region = "us-east-2"
}


module "msk_dr_region" {
  source = "../.."
  msk_config = {
    "sales-dr" = {
      "cluster" = {
        client_authentication = {
          sasl = {
            iam   = true
            scram = true
          }
        }
      }
    }
  }
}

output "dr" {
  value = module.msk_dr_region.name
}