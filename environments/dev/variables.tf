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

variable "db_name" {
  description = "PostgreSQL データベース名"
  type        = string
}

variable "db_username" {
  description = "PostgreSQL マスターユーザー名"
  type        = string
}

variable "task_cpu" {
  description = "ECS タスクの CPU ユニット数（256 / 512 / 1024 等）"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "ECS タスクのメモリ量（MiB）"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "ECS サービスの希望タスク数"
  type        = number
  default     = 1
}

variable "app_image_uri" {
  description = "ECS タスクで使用するコンテナイメージ URI（初回デプロイ時のデフォルト値）"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}
