output "terraform_role_arn" {
  description = "Set as AWS_TERRAFORM_ROLE_ARN in terraform-repo GitHub Secrets"
  value       = aws_iam_role.terraform.arn
}

output "app_deploy_role_arn" {
  description = "Set as AWS_DEPLOY_ROLE_ARN in app-repo GitHub Secrets"
  value       = aws_iam_role.app_deploy.arn
}

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
