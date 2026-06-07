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
  description = "Aurora クラスターに作成するデータベース名"
  type        = string
}

variable "db_username" {
  description = "Aurora クラスターのマスターユーザー名"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL エンジンバージョン。メジャーバージョンアップ時は engine_family と合わせて変更し terraform apply する"
  type        = string
  default     = "13.20"
}

variable "engine_family" {
  description = "パラメータグループのファミリ。メジャーバージョンアップ時は engine_version と合わせて変更する"
  type        = string
  default     = "aurora-postgresql13"
}

variable "cluster_parameter_group_name" {
  description = "Aurora クラスターに適用するパラメータグループ名。メジャーバージョンアップ時は engine_version / engine_family と合わせて変更する"
  type        = string
  default     = "default.aurora-postgresql13"
}

variable "cluster_instance_count" {
  description = "Aurora クラスターのインスタンス数"
  type        = number
  default     = 1
}
