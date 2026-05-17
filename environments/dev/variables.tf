variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "app_image_uri" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  description = "terraform-repo name"
  type        = string
}

variable "app_github_repo" {
  description = "app-repo name"
  type        = string
}
