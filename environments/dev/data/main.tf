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

  name_prefix                  = local.name_prefix
  vpc_id                       = data.terraform_remote_state.base.outputs.vpc_id
  private_subnet_ids           = data.terraform_remote_state.base.outputs.private_subnet_ids
  db_name                      = var.db_name
  db_username                  = var.db_username
  engine_version               = var.engine_version
  engine_family                = var.engine_family
  cluster_parameter_group_name = var.cluster_parameter_group_name
  cluster_instance_count       = var.cluster_instance_count
  kms_key_arn                  = data.terraform_remote_state.base.outputs.kms_key_arn
}
