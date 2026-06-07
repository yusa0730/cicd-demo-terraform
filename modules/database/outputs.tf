output "db_host" {
  description = "Aurora クラスターのライターエンドポイント"
  value       = aws_rds_cluster.this.endpoint
}

output "db_port" {
  description = "Aurora クラスターのポート番号"
  value       = aws_rds_cluster.this.port
}

output "rds_security_group_id" {
  description = "Aurora クラスターに紐づくセキュリティグループ ID"
  value       = aws_security_group.rds.id
}

output "database_url_secret_arn" {
  description = "Secrets Manager ARN storing the full DATABASE_URL connection string"
  value       = aws_secretsmanager_secret.database_url.arn
}
