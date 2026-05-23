output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ssm_prefix" {
  description = "Set as SSM_PREFIX in app-repo GitHub Variables"
  value       = local.ssm_prefix
}
