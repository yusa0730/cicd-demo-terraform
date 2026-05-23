output "terraform_plan_role_arns" {
  description = "Set as AWS_TERRAFORM_PLAN_ROLE_ARN_<ENV> in terraform-repo Repository Secrets"
  value = {
    for env, role in aws_iam_role.terraform_plan :
    env => role.arn
  }
}

output "terraform_apply_role_arns" {
  description = "Set as AWS_TERRAFORM_ROLE_ARN in terraform-repo GitHub Environment Secrets"
  value = {
    for env, role in aws_iam_role.terraform_apply :
    env => role.arn
  }
}

output "app_deploy_role_arns" {
  description = "Set as AWS_DEPLOY_ROLE_ARN in app-repo GitHub Environment Secrets"
  value = {
    for env, role in aws_iam_role.app_deploy :
    env => role.arn
  }
}

output "terraform_state_bucket_names" {
  value = {
    for env, bucket in aws_s3_bucket.terraform_state :
    env => bucket.bucket
  }
}
