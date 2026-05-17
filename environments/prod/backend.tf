terraform {
  backend "s3" {
    bucket       = "cicd-demo-terraform-prod"
    key          = "ecs-demo/prod/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
