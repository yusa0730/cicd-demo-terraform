variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "app_image_uri" {
  description = "Bootstrap image used only for initial Terraform apply. app-repo CI overwrites this via ECS task definition update."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "database_url_secret_arn" {
  description = "Secrets Manager ARN for DATABASE_URL injected into containers"
  type        = string
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

variable "container_port" {
  type    = number
  default = 3000
}

variable "kms_key_arn" {
  type = string
}
