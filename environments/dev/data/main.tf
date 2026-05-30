locals {
  name_prefix = "${var.project}-${var.env}"
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "cicd-demo-terraform-dev"
    key    = "ecs-demo/dev/base/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "database" {
  source = "../../../modules/database"

  name_prefix        = local.name_prefix
  vpc_id             = data.terraform_remote_state.base.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.base.outputs.private_subnet_ids
  db_name            = var.db_name
  db_username        = var.db_username
  kms_key_arn        = data.terraform_remote_state.base.outputs.kms_key_arn
}
