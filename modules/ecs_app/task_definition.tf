locals {
  container_base = {
    name      = "app"
    image     = var.app_image_uri
    essential = true

    portMappings = [
      { containerPort = var.container_port, protocol = "tcp" }
    ]

    environment = [
      { name = "PORT", value = tostring(var.container_port) }
    ]

    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = var.database_url_secret_arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "app"
      }
    }
  }
}

# Service task definition — runs the web server
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    merge(local.container_base, {
      command = ["npm", "run", "start:prod"]
    })
  ])
}

# Migration task definition — runs once per deploy, then stops
resource "aws_ecs_task_definition" "migration" {
  family                   = "${var.name_prefix}-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    merge(local.container_base, {
      command = ["npm", "run", "migrate:prod"]
    })
  ])
}
