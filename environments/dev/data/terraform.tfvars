project = "ecs-demo"
env     = "dev"

aws_region = "ap-northeast-1"

db_name     = "app"
db_username = "app_user"

# Aurora PostgreSQL 13 の最新版（ap-northeast-1 で利用可能: 13.9, 13.23）
# メジャーバージョンアップ手順:
#   1. engine_version を対象バージョン（例: "16.4"）に変更する
#   2. engine_family を対応するファミリ（例: "aurora-postgresql16"）に変更する
#   3. terraform plan で in-place update になることを確認する（replace でないこと）
#   4. terraform apply でアップグレードを実行する（数分〜十数分かかる）
#   5. アプリの /db-version エンドポイントで新バージョンを確認する
engine_version               = "13.9"
engine_family                = "aurora-postgresql13"
cluster_parameter_group_name = "default.aurora-postgresql13"
cluster_instance_count       = 1
