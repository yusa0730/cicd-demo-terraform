# terraform-repo

ECS on Fargate + RDS + ALB 構成を Terraform で管理する CI/CD デモリポジトリです。
GitHub Actions を使って、コードを push / PR merge するだけで AWS 環境への反映が自動で行われます。

## このリポジトリで何ができるか

- Terraform のコードを変更して PR を出すと、自動で `terraform plan` が実行され、何が変わるかを PR コメントで確認できます
- PR を approve してマージすると、自動で `terraform apply` が実行され、AWS 環境に変更が反映されます
- dev → stg → prod の順で変更を昇格させることで、本番環境への影響を最小限に抑えます
- prod 環境への apply は、承認者が plan 内容を確認してから実行できます

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [アーキテクチャ](docs/architecture.md) | AWS 構成・ネットワーク・ECS・RDS・IAM の詳細 |
| [CI/CD セットアップ](docs/cicd.md) | Workflows 一覧・セットアップ手順・Secrets 一覧 |

## リポジトリ構成

```
terraform-repo/
├── .github/
│   ├── CODEOWNERS                 # 各ディレクトリの承認者を定義
│   └── workflows/
│       ├── bootstrap-global.yml   # 【初回のみ】AWS の認証基盤（IAM Role）を作成する
│       ├── terraform-plan.yml     # 【PR 時】変更内容を確認する（apply はしない）
│       ├── terraform-apply.yml    # 【PR merge 時】AWS 環境に変更を反映する
│       └── terraform-destroy.yml  # 【手動】環境を削除する
│
├── bootstrap/                     # 認証基盤（初回のみ使用）
│   ├── dev/                       # dev AWS アカウント用
│   ├── stg/                       # stg AWS アカウント用
│   └── prod/                      # prod AWS アカウント用
│
├── environments/                  # 各環境の AWS リソース定義
│   ├── dev/                       # 開発環境（develop ブランチに対応）
│   ├── stg/                       # ステージング環境（stg ブランチに対応）
│   └── prod/                      # 本番環境（prod ブランチに対応）
│
├── modules/                       # 複数の環境で共通して使う部品
│   ├── network/                   # VPC, Subnet, NAT Gateway
│   ├── alb/                       # Application Load Balancer（インターネットからの入口）
│   ├── ecr/                       # コンテナイメージの保管場所
│   ├── ecs_app/                   # アプリケーションの実行基盤（ECS Fargate）
│   └── database/                  # データベース（RDS PostgreSQL）
│
└── docs/
    ├── architecture.md            # AWS 構成の詳細説明
    └── cicd.md                    # CI/CD のセットアップ手順
```

## 2 種類の Terraform スタック

このリポジトリでは、用途の異なる 2 種類の Terraform スタックを使い分けています。

### 1. bootstrap（初回のみ実行）

GitHub Actions が AWS を操作するために必要な **認証基盤** を作ります。
具体的には「GitHub Actions が AWS に安全にアクセスするための IAM Role」を作成します。

| 何を作るか | なぜ必要か |
|----------|----------|
| GitHub OIDC Provider | GitHub Actions が AWS に「自分は GitHub の正規のワークフローです」と証明するための仕組み |
| Terraform plan 用 IAM Role | PR 時に plan を実行するための権限（読み取り専用） |
| Terraform apply 用 IAM Role | merge 後に apply を実行するための権限（書き込みあり） |
| App deploy 用 IAM Role | app-repo が ECR にイメージを push したり ECS を更新するための権限 |

> S3 state バケット（`cicd-demo-terraform-{env}`）は bootstrap ワークフロー内の AWS CLI で作成します。Terraform では管理しません。

### 2. environments（日常的な開発サイクルで使用）

実際のアプリケーション基盤を作ります。

| 環境 | ブランチ | 内容 |
|-----|---------|-----|
| `environments/dev` | `develop` | VPC・ALB・ECS・RDS・ECR・SSM Parameter など |
| `environments/stg` | `stg` | 同上（ステージング） |
| `environments/prod` | `prod` | 同上（本番） |

environments を destroy しても、bootstrap で作った IAM Role や S3 バケットは削除されません。
そのため、destroy 後も GitHub Actions の認証は壊れず、再 apply が可能です。

## ブランチ戦略

変更は必ず feature ブランチから始め、dev → stg → prod の順に昇格させます。

```
feature/* → develop → stg → prod
```

```
[開発者]
   │
   ├─ feature/xxx ブランチを作成
   │
   ├─ develop へ PR → terraform-plan が自動実行（変更内容を確認）
   │
   ├─ approve して merge → terraform-apply が自動実行（dev 環境に反映）
   │
   ├─ develop → stg へ PR → merge → stg 環境に反映
   │
   └─ stg → prod へ PR → merge → prod-plan 実行 → 承認者が確認 → prod 環境に反映
```

直接 push しても apply は実行されません。必ず PR 経由のマージが必要です。

## GitHub Actions の認証設計

パスワードや長期的なアクセスキーを GitHub に保存しません。
代わりに **GitHub OIDC** という仕組みを使い、ワークフロー実行のたびに一時的な認証情報を取得します。

```
GitHub Actions ワークフロー
    │
    │ 「私は github.com/yusa0730/cicd-demo-terraform の正規ワークフローです」
    ▼
GitHub OIDC Provider（AWS IAM）
    │
    │ 検証 OK → 一時的な認証情報を発行
    ▼
IAM Role を Assume
    │
    ├─ terraform-plan-role  → plan のみ実行可能
    ├─ terraform-apply-role → apply / destroy 実行可能
    └─ app-deploy-role      → ECR push / ECS 更新のみ実行可能
```

どの操作にどの Role が使われるかは以下の通りです。

| ワークフロー・ステップ | 使用する Role | 条件 |
|---------------------|-------------|-----|
| PR の plan | `terraform-plan-role` | PR からのトリガー |
| destroy-plan | `terraform-plan-role` | ブランチ（`develop` / `stg` / `prod`）からのトリガー |
| merge 後の apply | `terraform-apply-role` | GitHub Environment の承認通過後 |
| destroy-apply | `terraform-apply-role` | GitHub Environment の承認通過後 |
| app-repo からの deploy | `app-deploy-role` | app-repo の GitHub Environment 通過後 |

## GitHub Secrets / Variables の一覧

### Repository Secrets

| 名前 | 用途 | 登録タイミング |
|-----|-----|-------------|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | dev 環境の plan 用 IAM Role ARN | bootstrap-dev 完了後 |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | stg 環境の plan 用 IAM Role ARN | bootstrap-stg 完了後 |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | prod 環境の plan 用 IAM Role ARN | bootstrap-prod 完了後 |

### Repository Variables（任意）

| 名前 | デフォルト値 | 用途 |
|-----|------------|-----|
| `AWS_REGION` | `ap-northeast-1` | 使用する AWS リージョン |

### GitHub Environments

`Settings → Environments` で以下の Environment を作成し、それぞれに Secret を登録します。

| Environment | Secret 名 | 用途 | 登録タイミング |
|------------|-----------|-----|-------------|
| `dev` | `AWS_TERRAFORM_ROLE_ARN` | dev apply / destroy 用 IAM Role ARN | bootstrap-dev 完了後 |
| `stg` | `AWS_TERRAFORM_ROLE_ARN` | stg apply / destroy 用 IAM Role ARN | bootstrap-stg 完了後 |
| `prod` | `AWS_TERRAFORM_ROLE_ARN` | prod apply / destroy 用 IAM Role ARN | bootstrap-prod 完了後 |
| `bootstrap-dev` | `AWS_BOOTSTRAP_ACCESS_KEY_ID` | bootstrap 実行用（完了後に削除） | bootstrap 実行前 |
| `bootstrap-dev` | `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | bootstrap 実行用（完了後に削除） | bootstrap 実行前 |
| `bootstrap-stg` | 同上 | stg アカウント用 | bootstrap 実行前 |
| `bootstrap-prod` | 同上 | prod アカウント用 | bootstrap 実行前 |
