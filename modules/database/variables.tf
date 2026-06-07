variable "name_prefix" {
  description = "リソース名の先頭に付与するプレフィックス（例: ecs-demo-dev）"
  type        = string
}

variable "vpc_id" {
  description = "Aurora クラスターを配置する VPC の ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Aurora サブネットグループに使用するプライベートサブネット ID のリスト"
  type        = list(string)
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
  description = "Aurora PostgreSQL エンジンバージョン（例: \"13.20\", \"16.4\"）。メジャーバージョンアップ時は engine_family と合わせて変更する"
  type        = string
  default     = "13.20"
}

variable "engine_family" {
  description = "Aurora PostgreSQL パラメータグループのファミリ（例: \"aurora-postgresql13\", \"aurora-postgresql16\"）。メジャーバージョンアップ時は engine_version と合わせて変更する"
  type        = string
  default     = "aurora-postgresql13"
}

variable "cluster_parameter_group_name" {
  description = "Aurora クラスターに適用するパラメータグループ名。デフォルトは AWS 管理のデフォルトパラメータグループ。メジャーバージョンアップ時は対応するバージョンのデフォルト名（例: \"default.aurora-postgresql16\"）に変更する"
  type        = string
  default     = "default.aurora-postgresql13"
}

variable "cluster_instance_count" {
  description = "Aurora クラスターのインスタンス数（1 = writer のみ、2 以上 = writer + reader）"
  type        = number
  default     = 1
}

variable "instance_class" {
  description = "Aurora クラスターインスタンスのインスタンスクラス"
  type        = string
  default     = "db.t3.medium"
}

variable "deletion_protection" {
  description = "Aurora クラスターの削除保護。本番環境では true を推奨"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Aurora クラスターのバックアップ保持期間（日数）"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "Secrets Manager および Aurora ストレージ暗号化に使用する KMS キーの ARN"
  type        = string
}
