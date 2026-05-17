# terraform-repo

ECS on Fargate + RDS + ALB 構成を Terraform で管理する CI/CD デモリポジトリです。
GitHub Actions による PR plan / merge apply を使い、dev → stg → prod の順で変更を昇格させます。

## リポジトリ構成

```
terraform-repo/
├── environments/
│   ├── dev/          # 開発環境
│   ├── stg/          # ステージング環境
│   └── prod/         # 本番環境
└── modules/
    ├── network/      # VPC, Subnet, NAT Gateway
    ├── alb/          # Application Load Balancer
    ├── ecr/          # ECR リポジトリ
    ├── ecs_app/      # ECS Cluster, Service, Task Definition
    └── database/     # RDS (PostgreSQL)
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

---

## セットアップ手順

### 前提条件

- AWS CLI がインストールされていること
- Terraform 1.9.0 以上がインストールされていること
- 初回 apply を実行できる AWS 権限を持つユーザーがいること

---

### Step 1: コードの修正

以下のプレースホルダーを実際の値に置き換えます。

**`environments/*/backend.tf`（3 ファイル）**

```hcl
bucket = "your-terraform-state-bucket"  # 作成する S3 バケット名に変更
```

**`environments/*/terraform.tfvars`（3 ファイル）**

```hcl
github_org      = "your-org"   # GitHub ユーザー名または組織名に変更
github_repo     = "terraform-repo"
app_github_repo = "app-repo"
```

---

### Step 2: AWS リソースの手動作成

GitHub Actions を動かすために、S3 バケットと IAM Role を先に作成します。
IAM Role は Terraform で管理しているため、**最初の 1 回だけローカルから手動 apply** します。

#### 2-1. Terraform state 用 S3 バケットを作成

```bash
BUCKET_NAME="your-terraform-state-bucket"
REGION="ap-northeast-1"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled
```

#### 2-2. ローカルの AWS 認証情報を設定

```bash
aws configure
# または
export AWS_PROFILE=your-profile
```

初回 apply には以下の権限が必要です。

- S3（state の読み書き）
- EC2, ECS, ECR, RDS, IAM, ELB, CloudWatch, Secrets Manager, SSM

#### 2-3. dev 環境を手動 apply

dev 環境の apply で GitHub OIDC Provider と IAM Role が作成されます。

```bash
cd environments/dev
terraform init
terraform apply
```

apply 完了後、以降の手順で必要な ARN を取得します。

```bash
terraform output terraform_role_arn
terraform output app_deploy_role_arn
```

#### 2-4. stg / prod 環境を手動 apply

stg・prod は dev で作成された GitHub OIDC Provider を参照します。

```bash
cd ../stg
terraform init
terraform apply
terraform output terraform_role_arn
terraform output app_deploy_role_arn

cd ../prod
terraform init
terraform apply
terraform output terraform_role_arn
terraform output app_deploy_role_arn
```

---

### Step 3: GitHub リポジトリの設定

#### 3-1. Repository Secrets の登録

`Settings → Secrets and variables → Actions → New repository secret`

PR 時の terraform plan で使用する read 権限の IAM Role を登録します。

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | dev の `terraform output terraform_role_arn` |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | stg の `terraform output terraform_role_arn` |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | prod の `terraform output terraform_role_arn` |

#### 3-2. GitHub Environments の作成

`Settings → Environments → New environment` で以下の 3 つを作成します。

**Environment: `dev`**

| 項目 | 値 |
|-----|---|
| Environment Secrets → `AWS_TERRAFORM_ROLE_ARN` | dev の `terraform output terraform_role_arn` |

**Environment: `stg`**

| 項目 | 値 |
|-----|---|
| Environment Secrets → `AWS_TERRAFORM_ROLE_ARN` | stg の `terraform output terraform_role_arn` |

**Environment: `prod`**

| 項目 | 値 |
|-----|---|
| Environment Secrets → `AWS_TERRAFORM_ROLE_ARN` | prod の `terraform output terraform_role_arn` |
| Required reviewers | 承認者を追加（必須） |

#### 3-3. Branch Protection Rules の設定

`Settings → Branches → Add branch ruleset` で `develop` / `stg` / `prod` それぞれに設定します。

| 項目 | 値 |
|-----|---|
| Require a pull request before merging | ✅ |
| Require approvals | ✅ (1 以上) |
| Require review from Code Owners | ✅ |
| Require status checks to pass before merging | ✅ |
| Required status checks | `terraform-plan / fmt`, `terraform-plan / plan` |

---

### Step 4: 動作確認

設定が完了したら、以下の流れで動作を確認します。

```
1. feature ブランチを作成して develop へ PR を出す
   → terraform-plan が自動実行される
   → PR コメントに validate / plan の結果が表示される

2. PR を approve して develop へ merge する
   → terraform-apply が自動実行される
   → dev 環境に apply される

3. develop → stg へ PR を出して merge する
   → stg 環境に apply される

4. stg → prod へ PR を出して merge する
   → prod-plan が自動実行される（Step Summary に plan 全文が表示される）
   → 承認者が内容を確認して「Approve and deploy」をクリックする
   → prod 環境に apply される
```

---

## Secrets / Variables 一覧

### Repository Secrets

| 名前 | 用途 |
|-----|-----|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | dev plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | stg plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | prod plan 用 IAM Role ARN |

### Repository Variables（任意）

| 名前 | デフォルト値 | 用途 |
|-----|------------|-----|
| `AWS_REGION` | `ap-northeast-1` | AWS リージョン |

### Environment Secrets（各 Environment に設定）

| 名前 | 用途 |
|-----|-----|
| `AWS_TERRAFORM_ROLE_ARN` | apply 用 IAM Role ARN（Environment ごとに別の ARN を設定） |
