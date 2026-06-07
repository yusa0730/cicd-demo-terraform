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
  secret_string = "postgresql://${var.db_username}:${random_password.db.result}@${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}/${var.db_name}?sslmode=require"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-instance-pg"
  family = var.engine_family
}

# Ingress rules are added at the environment level to avoid circular dependency with ecs_app module.
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security Group to ${var.name_prefix}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier              = "${var.name_prefix}-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.engine_version
  master_username                 = var.db_username
  master_password                 = random_password.db.result
  database_name                   = var.db_name
  port                            = 5432
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = var.cluster_parameter_group_name
  storage_encrypted               = true
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = "01:00-02:00"
  preferred_maintenance_window    = "wed:00:00-wed:01:00"
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  lifecycle {
    ignore_changes = [
      db_cluster_parameter_group_name,
      global_cluster_identifier,
      replication_source_identifier,
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.cluster_instance_count

  identifier              = "${var.name_prefix}-cluster-${count.index}"
  cluster_identifier      = aws_rds_cluster.this.id
  instance_class          = var.instance_class
  engine                  = "aurora-postgresql"
  engine_version          = var.engine_version
  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name
  monitoring_role_arn     = aws_iam_role.monitoring.arn
  monitoring_interval     = 60

  apply_immediately            = true
  auto_minor_version_upgrade   = false
  performance_insights_enabled = false
}

resource "aws_iam_role" "monitoring" {
  name = "${var.name_prefix}-rds-monitoring"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
