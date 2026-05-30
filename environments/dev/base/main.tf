locals {
  name_prefix = "${var.project}-${var.env}"
}

module "kms" {
  source      = "../../../modules/kms"
  name_prefix = local.name_prefix
}

module "network" {
  source = "../../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  kms_key_arn          = module.kms.key_arn
}
