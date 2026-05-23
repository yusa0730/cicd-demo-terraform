resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.name_prefix}/database-url"
  recovery_window_in_days = 0
  kms_key_id              = var.kms_key_arn
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}?sslmode=require"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet"
  subnet_ids = var.private_subnet_ids
}

# Ingress rules are added at the environment level to avoid circular dependency with ecs_app module.
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS - ingress rules managed by environment root"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-rds-sg" }
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name_prefix}-db"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  deletion_protection     = var.deletion_protection
  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period

  storage_encrypted          = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn

  tags = { Name = "${var.name_prefix}-db" }
}
