output "terraform_plan_role_arn" {
  description = "Set as AWS_TERRAFORM_PLAN_ROLE_ARN_PROD in terraform-repo Repository Secrets"
  value       = aws_iam_role.terraform_plan.arn
}

output "terraform_apply_role_arn" {
  description = "Set as AWS_TERRAFORM_ROLE_ARN in terraform-repo GitHub Environment prod"
  value       = aws_iam_role.terraform_apply.arn
}

output "app_deploy_role_arn" {
  description = "Set as AWS_DEPLOY_ROLE_ARN in app-repo GitHub Environment prod"
  value       = aws_iam_role.app_deploy.arn
}
