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

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}
