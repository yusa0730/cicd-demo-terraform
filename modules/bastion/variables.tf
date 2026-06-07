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

variable "database_url_secret_arn" {
  description = "Aurora 接続情報を格納した Secrets Manager シークレットの ARN（bastion から psql 接続する際に参照）"
  type        = string
}

variable "kms_key_arn" {
  description = "Secrets Manager シークレットの暗号化に使用する KMS キーの ARN（bastion から復号するために必要）"
  type        = string
}
