terraform {
  backend "s3" {
    bucket       = "cicd-demo-terraform-stg"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
