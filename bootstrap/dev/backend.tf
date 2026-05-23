terraform {
  backend "s3" {
    bucket       = "cicd-demo-terraform-dev"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
