output "db_host" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "database_url_secret_arn" {
  description = "Secrets Manager ARN storing the full DATABASE_URL connection string"
  value       = aws_secretsmanager_secret.database_url.arn
}
