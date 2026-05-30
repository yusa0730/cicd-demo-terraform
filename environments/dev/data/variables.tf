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

variable "db_name" {
  description = "PostgreSQL データベース名"
  type        = string
}

variable "db_username" {
  description = "PostgreSQL マスターユーザー名"
  type        = string
}
