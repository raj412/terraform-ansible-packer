# having multiple providers allows terraform to orchestrate changes accross multiple-accounts
provider "aws" {
  alias      = "infra_net_mgm_dev"
  access_key = var.infra_net_mgm_dev_AWS_ACCESS_KEY_ID
  secret_key = var.infra_net_mgm_dev_AWS_SECRET_ACCESS_KEY
  region     = var.infra_net_mgm_dev_AWS_DEFAULT_REGION
}

