variable "name_prefix" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "vpc_id" {
  description = "Bastion を配置する VPC の ID"
  type        = string
}

variable "subnet_id" {
  description = "Bastion を配置するプライベートサブネットの ID（NAT Gateway 経由で SSM に到達）"
  type        = string
}

variable "instance_type" {
  description = "EC2 インスタンスタイプ"
  type        = string
  default     = "t3.nano"
}
