locals {
  name_prefix    = "${var.project}-${var.env}"
  ssm_prefix     = "/${var.project}/${var.env}"
  container_port = 3000
}

module "kms" {
  source      = "../../modules/kms"
  name_prefix = local.name_prefix
}

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  kms_key_arn          = module.kms.key_arn
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.name_prefix
  kms_key_arn = module.kms.key_arn
}

module "database" {
  source = "../../modules/database"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  db_name            = var.db_name
  db_username        = var.db_username
  kms_key_arn        = module.kms.key_arn
}

module "alb" {
  source = "../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  container_port    = local.container_port
}

module "ecs_app" {
  source = "../../modules/ecs_app"

  name_prefix           = local.name_prefix
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  container_port        = local.container_port
  kms_key_arn           = module.kms.key_arn

  app_image_uri           = var.app_image_uri
  database_url_secret_arn = module.database.database_url_secret_arn

  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count
}

# Break circular SG dependency: ecs_app creates ECS SG, database creates RDS SG,
# and we wire the ingress rule here after both are known.
resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ecs_app.ecs_security_group_id
  security_group_id        = module.database.rds_security_group_id
  description              = "Allow PostgreSQL from ECS tasks"
}

# Egress rules defined here to avoid circular SG dependencies in modules.
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = module.alb.alb_security_group_id
  referenced_security_group_id = module.ecs_app.ecs_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
  description                  = "Allow ALB to ECS tasks"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = module.ecs_app.ecs_security_group_id
  referenced_security_group_id = module.database.rds_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Allow ECS tasks to PostgreSQL"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_https" {
  security_group_id = module.ecs_app.ecs_security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Allow HTTPS outbound for AWS APIs and image pulls"
}

# SSM Parameter Store — values published for app-repo CI to consume
locals {
  ssm_params = {
    ecr-repository-url     = module.ecr.repository_url
    ecs-cluster-name       = module.ecs_app.cluster_name
    ecs-service-name       = module.ecs_app.service_name
    task-definition-family = module.ecs_app.task_definition_family
    migration-task-def-arn = module.ecs_app.migration_task_definition_arn
    ecs-subnet-ids         = join(",", module.network.private_subnet_ids)
    ecs-security-group-id  = module.ecs_app.ecs_security_group_id
    alb-dns-name           = module.alb.alb_dns_name
  }
}

resource "aws_ssm_parameter" "infra" {
  for_each = local.ssm_params

  name   = "${local.ssm_prefix}/${each.key}"
  type   = "SecureString"
  value  = each.value
  key_id = module.kms.key_arn
}
