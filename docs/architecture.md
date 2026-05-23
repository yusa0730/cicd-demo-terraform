# アーキテクチャ

## 構成概要

ECS on Fargate + RDS (PostgreSQL) + ALB 構成です。
アプリコンテナはプライベートサブネット上で動作し、インターネットからの直接アクセスは ALB 経由のみ許可します。

## AWS構成図

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ VPC (10.x.0.0/16)                                       │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Public Subnet (AZ-a / AZ-c)                      │   │
│  │                                                  │   │
│  │  ┌────────────┐     ┌─────────────┐              │   │
│  │  │    ALB     │     │ NAT Gateway │              │   │
│  │  │  (port 80) │     │             │              │   │
│  │  └─────┬──────┘     └──────┬──────┘              │   │
│  └────────┼───────────────────┼─────────────────────┘   │
│           │                   │                         │
│  ┌────────┼───────────────────┼─────────────────────┐   │
│  │ Private Subnet (AZ-a / AZ-c)                     │   │
│  │        │                   │ (outbound)          │   │
│  │        ▼                   │                     │   │
│  │  ┌───────────┐             │                     │   │
│  │  │ ECS Task  │─────────────┘                     │   │
│  │  │ (Fargate) │                                   │   │
│  │  │ app       │──────────────────┐                │   │
│  │  │ migration │                  ▼                │   │
│  │  └───────────┘          ┌──────────────┐         │   │
│  │                         │  RDS (PgSQL) │         │   │
│  │                         └──────────────┘         │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

外部サービス:
  ECR           ← ECS がコンテナイメージを pull
  Secrets Manager ← ECS が DATABASE_URL を取得
  SSM Parameter Store ← app-repo CI がインフラ情報を参照
  CloudWatch Logs ← ECS コンテナのログ出力先
```

## ネットワーク

| リソース | 配置 | 説明 |
|---------|------|------|
| ALB | パブリックサブネット | インターネット向け HTTP(80) を受け付ける |
| NAT Gateway | パブリックサブネット (AZ-a) | プライベートサブネットからの外部通信を中継 |
| ECS Fargate | プライベートサブネット | `assign_public_ip = false`。外部通信は NAT 経由 |
| RDS | プライベートサブネット | `publicly_accessible = false` |

### CIDR 割り当て

| 環境 | VPC | パブリック | プライベート |
|-----|-----|----------|------------|
| dev | `10.0.0.0/16` | `10.0.1.0/24`, `10.0.2.0/24` | `10.0.11.0/24`, `10.0.12.0/24` |
| stg | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24` | `10.1.11.0/24`, `10.1.12.0/24` |
| prod | `10.2.0.0/16` | `10.2.1.0/24`, `10.2.2.0/24` | `10.2.11.0/24`, `10.2.12.0/24` |

## セキュリティグループ

```
Internet → ALB SG (80/tcp inbound)
ALB SG   → ECS SG (container_port inbound from ALB SG)
ECS SG   → RDS SG (5432/tcp inbound from ECS SG)
```

> ECS SG と RDS SG の間の ingress rule は環境ルート (`environments/*/main.tf`) で定義します。
> これは ecs_app モジュールと database モジュールの循環依存を避けるための設計です。

## ECS

### クラスター / サービス

| 項目 | 値 |
|-----|---|
| 起動タイプ | Fargate |
| デプロイ方式 | Rolling update |
| Circuit breaker | 有効（失敗時に自動ロールバック） |
| task_definition の管理 | `lifecycle { ignore_changes = [task_definition] }` により app-repo CI が管理 |

### タスク定義

同一のコンテナ設定（イメージ・環境変数・シークレット・ログ設定）をベースに、`command` だけを差し替えた 2 つのタスク定義を持ちます。

| タスク定義 | command | 用途 |
|-----------|---------|------|
| `{prefix}-app` | `["npm", "run", "start"]` | 常駐 Web サーバー（ECS Service で管理） |
| `{prefix}-migration` | `["npm", "run", "migrate"]` | DB マイグレーション（デプロイ時に one-off 実行） |

### ECS IAM ロール

| ロール | 用途 |
|------|------|
| Execution Role | ECS エージェントが ECR からイメージ pull・Secrets Manager からシークレット取得に使用 |
| Task Role | 実行中コンテナが AWS サービスを呼び出す際に使用（初期は空権限） |

## データストア

### RDS (PostgreSQL 16)

| 項目 | dev / stg | prod |
|-----|----------|------|
| インスタンスクラス | `db.t3.micro` | `db.t3.micro` |
| Multi-AZ | false | false |
| パブリックアクセス | false | false |
| 削除保護 | false | false |
| バックアップ保持 | 0日 | 0日 |

> デモ構成のため削除保護・バックアップを無効にしています。本番では有効化してください。

### Secrets Manager

| シークレット名 | 内容 |
|-------------|------|
| `{prefix}/database-url` | `postgresql://user:pass@host:5432/dbname?sslmode=require` 形式の接続文字列 |

ECS タスク起動時に環境変数 `DATABASE_URL` としてコンテナに注入されます。

## SSM Parameter Store

terraform-repo が書き込み、app-repo CI が読み取るインフラ情報の受け渡し場所です。

| パラメータ名 | 値 |
|-----------|---|
| `/{project}/{env}/ecr-repository-url` | ECR リポジトリ URL |
| `/{project}/{env}/ecs-cluster-name` | ECS クラスター名 |
| `/{project}/{env}/ecs-service-name` | ECS サービス名 |
| `/{project}/{env}/task-definition-family` | アプリ用タスク定義ファミリー |
| `/{project}/{env}/migration-task-def-arn` | マイグレーション用タスク定義 ARN |
| `/{project}/{env}/ecs-subnet-ids` | ECS タスク起動用サブネット ID（カンマ区切り） |
| `/{project}/{env}/ecs-security-group-id` | ECS タスク用セキュリティグループ ID |
| `/{project}/{env}/alb-dns-name` | ALB の DNS 名 |

## IAM（GitHub Actions 用）

GitHub OIDC を使用し、長期 credentials を持たない設計です。

```
GitHub Actions
    │
    │ (OIDC Token)
    ▼
GitHub OIDC Provider (IAM)  ← bootstrap/<env> で環境ごとに作成
    │
    │ sts:AssumeRoleWithWebIdentity
    ├─▶ terraform-plan-role   ← terraform plan / destroy-plan
    ├─▶ terraform-apply-role  ← terraform apply / destroy-apply
    └─▶ app-deploy-role       ← ECR push / ECS deploy
```

### IAM ロール一覧

| ロール名 | 用途 | OIDC sub 条件 |
|--------|------|--------------|
| `{project}-{env}-terraform-plan-role` | plan / destroy-plan | `pull_request` または `ref:refs/heads/{branch}` |
| `{project}-{env}-terraform-apply-role` | apply / destroy-apply | `environment:{env}` |
| `{project}-{env}-app-deploy-role` | ECR push・ECS タスク更新 | `environment:{env}` |

### bootstrap 設計

OIDC Provider と IAM ロールは `bootstrap/<env>/` で管理します。環境ごとに独立した Terraform stack を持ち、それぞれ別の AWS アカウントに対して実行できます。

| ディレクトリ | 対象アカウント | 管理リソース |
|-----------|------------|------------|
| `bootstrap/dev` | dev アカウント | OIDC Provider・IAM ロール 3 本 |
| `bootstrap/stg` | stg アカウント | OIDC Provider・IAM ロール 3 本 |
| `bootstrap/prod` | prod アカウント | OIDC Provider・IAM ロール 3 本 |

S3 state バケット（`cicd-demo-terraform-{env}`）は bootstrap workflow の AWS CLI ステップで作成・設定します。Terraform では管理しません（循環依存を避けるため）。

## Terraform モジュール構成

```
modules/
├── network/    VPC・サブネット・IGW・NAT Gateway・ルートテーブル
├── alb/        ALB・ターゲットグループ・リスナー・セキュリティグループ
├── ecr/        ECR リポジトリ
├── ecs_app/    ECS クラスター・サービス・タスク定義・IAM ロール・CloudWatch Logs
└── database/   RDS インスタンス・Secrets Manager・セキュリティグループ
```

各環境 (`environments/dev`, `stg`, `prod`) はこれらのモジュールを組み合わせて構成します。
ECS SG → RDS SG の ingress rule のみ、循環依存を避けるために環境ルートで定義します。

## 環境別スペック

| 項目 | dev | stg | prod |
|-----|-----|-----|------|
| ECS CPU | 512 | 512 | 1024 |
| ECS Memory | 1024 MB | 1024 MB | 2048 MB |
| 希望タスク数 | 1 | 1 | 2 |
