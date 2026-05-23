# OIDC Provider import has been moved to bootstrap/global/imports.tf.

# Resources that exist in AWS from a previous partial apply but are not in state.
# Remove each import block after the first successful `terraform apply` that includes it.

import {
  to = module.alb.aws_lb_target_group.this
  id = "arn:aws:elasticloadbalancing:ap-northeast-1:218317313594:targetgroup/ecs-demo-dev-tg/c2d8aff70b36b682"
}

import {
  to = module.database.aws_secretsmanager_secret.database_url
  id = "arn:aws:secretsmanager:ap-northeast-1:218317313594:secret:ecs-demo-dev/database-url-OUdlZT"
}

import {
  to = module.database.aws_db_subnet_group.this
  id = "ecs-demo-dev-db-subnet"
}

import {
  to = module.database.aws_security_group.rds
  id = "sg-0d05ac95b2f1ba1fe"
}

import {
  to = module.ecs_app.aws_iam_role.execution
  id = "ecs-demo-dev-ecs-execution-role"
}

import {
  to = module.ecs_app.aws_iam_role.task
  id = "ecs-demo-dev-ecs-task-role"
}

import {
  to = module.ecs_app.aws_cloudwatch_log_group.app
  id = "/ecs/ecs-demo-dev/app"
}

import {
  to = module.ecs_app.aws_security_group.ecs
  id = "sg-0b8d8f565d2b5887b"
}
