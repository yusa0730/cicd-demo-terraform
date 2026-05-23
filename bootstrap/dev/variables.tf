variable "project" {
  type    = string
  default = "ecs-demo"
}

variable "github_owner" {
  type    = string
  default = "yusa0730"
}

variable "terraform_repo" {
  type    = string
  default = "cicd-demo-terraform"
}

variable "app_repo" {
  type    = string
  default = "cicd-demo-backend"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}
