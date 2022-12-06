#################################################################################
# This holds the configuration for terraform to enable an S3 backend            #
# for terraform state files With a dynamo DB locking to prevent multiple applys #
#################################################################################

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "aws_dynamodb_table_name"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

###################################################################################################
# For setup, do a terraform init, plan and plana with this section commented out                  #
# Then uncomment this section and run a terraform init - This will initialise the remote backend. #
###################################################################################################

terraform {
  backend "s3" {
    bucket         = "bucket-name"
    key            = "terraform-state/dev-infra-net-mgm-dev/global/s3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "dev-terraform-up-and-running-locks"
    encrypt        = true
  }
}
