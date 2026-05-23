terraform {
  backend "s3" {
    bucket       = "cicd-demo-terraform-global"
    key          = "bootstrap/global/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
