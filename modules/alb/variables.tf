variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "health_check_path" {
  description = "ALB ターゲットグループのヘルスチェックパス"
  type        = string
  default     = "/health-check"
}
