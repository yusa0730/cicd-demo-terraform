terraform {
  backend "s3" {
    bucket       = "your-terraform-state-bucket"
    key          = "ecs-demo/dev/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
