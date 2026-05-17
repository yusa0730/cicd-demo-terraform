# terraform-repo

ECS on Fargate + RDS + ALB 構成を Terraform で管理する CI/CD デモリポジトリです。
GitHub Actions による PR plan / merge apply を使い、dev → stg → prod の順で変更を昇格させます。

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [アーキテクチャ](docs/architecture.md) | AWS 構成・ネットワーク・ECS・RDS・IAM の詳細 |
| [CI/CD セットアップ](docs/cicd.md) | Workflows 一覧・セットアップ手順・Secrets 一覧 |

## リポジトリ構成

```
terraform-repo/
├── .github/
│   ├── CODEOWNERS
│   └── workflows/
│       ├── bootstrap.yml          # 初回: 環境を選んで IAM Role / S3 を作成
│       ├── terraform-plan.yml     # PR 時: terraform plan を実行して結果をコメント
│       ├── terraform-apply.yml    # merge 時: terraform apply を実行
│       └── terraform-destroy.yml  # 手動: 環境を削除
├── docs/
│   ├── architecture.md            # AWS 構成・モジュール説明
│   └── cicd.md                    # CI/CD セットアップ手順
├── environments/
│   ├── dev/                       # 開発環境
│   ├── stg/                       # ステージング環境
│   └── prod/                      # 本番環境
└── modules/
    ├── network/                   # VPC, Subnet, NAT Gateway
    ├── alb/                       # Application Load Balancer
    ├── ecr/                       # ECR リポジトリ
    ├── ecs_app/                   # ECS Cluster, Service, Task Definition
    └── database/                  # RDS (PostgreSQL)
```

## ブランチ戦略

```
feature/* → develop → stg → prod
```

| ブランチ | 対応環境 |
|---------|---------|
| `develop` | `environments/dev` |
| `stg` | `environments/stg` |
| `prod` | `environments/prod` |

PR をマージすると対応環境へ自動 apply されます。prod のみ apply 前に承認が必要です。
