variable "project" {
  description = "プロジェクト名（name_prefix の先頭部分）"
  type        = string
}

variable "env" {
  description = "環境名（dev / stg / prod）"
  type        = string
}

variable "aws_region" {
  description = "デプロイ先 AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
}

variable "availability_zones" {
  description = "サブネットを作成するアベイラビリティゾーンのリスト"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットの CIDR ブロックのリスト（availability_zones と順序を合わせること）"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットの CIDR ブロックのリスト（availability_zones と順序を合わせること）"
  type        = list(string)
}
