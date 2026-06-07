output "database_url_secret_arn" {
  value = module.database.database_url_secret_arn
}

output "rds_security_group_id" {
  value = module.database.rds_security_group_id
}
