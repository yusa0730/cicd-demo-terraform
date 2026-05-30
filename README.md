# terraform-repo

ECS on Fargate + RDS + ALB 構成を Terraform で管理する CI/CD デモリポジトリです。

## リポジトリ構成

| リポジトリ | 責務 |
|-----------|------|
| `terraform-bootstrap` | OIDC Provider・IAM ロール（CI/CD 認証基盤） |
| `terraform-accounts` | GuardDuty・CloudTrail・Config 等のアカウントセキュリティ基盤 |
| `terraform-repo`（このリポジトリ） | VPC・ECS・RDS・ALB・ECR 等のアプリ実行基盤 |
| `app-repo` | アプリケーションコード・ECS デプロイ |

### environments/\<env\> の責務

実際のアプリケーション実行基盤を管理します。

- VPC / ALB / ECS / RDS / ECR
- SSM Parameter Store
- Secrets Manager

GitHub Actions → AWS 認証に使う IAM ロールと OIDC Provider は `terraform-bootstrap` で管理します。
`terraform-destroy` で `environments/<env>` を削除しても、IAM ロールや OIDC Provider は削除されません。

---

## Terraform State 分離設計

### State レイヤー構成

`environments/<env>` は以下の 3 レイヤーに分割します。
各レイヤーが独立した S3 バックエンドキーを持ち、ライフサイクルが異なるリソースを分離します。

| レイヤー | ディレクトリ | 管理リソース | S3 バックエンドキー |
|---------|-------------|-------------|-------------------|
| `base`  | `environments/<env>/base/` | KMS, VPC/Network | `ecs-demo/<env>/base/terraform.tfstate` |
| `data`  | `environments/<env>/data/` | RDS, Secrets Manager | `ecs-demo/<env>/data/terraform.tfstate` |
| `app`   | `environments/<env>/app/`  | ECR, ALB, ECS, SSM params, SG rules | `ecs-demo/<env>/app/terraform.tfstate` |

### クロス State 参照

`data` と `app` は `terraform_remote_state` で上位レイヤーの出力を参照します。

```
base  →  data  (vpc_id, private_subnet_ids, kms_key_arn)
base  →  app   (vpc_id, public/private_subnet_ids, kms_key_arn)
data  →  app   (database_url_secret_arn, rds_security_group_id)
```

### Apply 順序

State 間に依存があるため、apply は以下の順で実行します。

```
1. environments/<env>/base/   ← KMS + Network
2. environments/<env>/data/   ← RDS (base の output を参照)
3. environments/<env>/app/    ← ECR / ALB / ECS (base + data の output を参照)
```

destroy は apply の逆順（app → data → base）で実行します。

### 現行 State との関係

`environments/<env>/` 直下の単一 State（`ecs-demo/<env>/terraform.tfstate`）は現在も稼働中です。
`base` / `data` / `app` への移行（State 分割）は段階的に行います。

- **PR 1（このブランチ）**: `base` / `data` / `app` ディレクトリの作成（ファイル追加のみ、既存 State 変更なし）
- **PR 2**: `terraform state mv` による State 移行 + workflow 更新（dev）
- **PR 3**: stg / prod への展開

---

## はじめに

このリポジトリを初めて使うときは、以下の手順で環境を構築してください。

> **前提条件**: `terraform-bootstrap` の bootstrap が完了していること。
> bootstrap 手順は [terraform-bootstrap の README](../terraform-bootstrap/README.md) を参照してください。

---

### Step 1: GitHub に Secrets / Environments を登録する

`terraform-bootstrap` の apply 完了後、Step Summary に表示された ARN を以下に登録します。

#### terraform-repo の Repository Secrets

`Settings → Secrets and variables → Actions → Repository secrets`

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | bootstrap Step Summary の `terraform_plan_role_arn`（dev） |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | bootstrap Step Summary の `terraform_plan_role_arn`（stg） |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | bootstrap Step Summary の `terraform_plan_role_arn`（prod） |

#### terraform-repo の GitHub Environments

`Settings → Environments` で `dev` / `stg` / `prod` を作成します。

| Environment | Secret 名 | 値 |
|------------|-----------|---|
| `dev` | `AWS_TERRAFORM_ROLE_ARN` | bootstrap Step Summary の `terraform_apply_role_arn`（dev） |
| `stg` | `AWS_TERRAFORM_ROLE_ARN` | bootstrap Step Summary の `terraform_apply_role_arn`（stg） |
| `prod` | `AWS_TERRAFORM_ROLE_ARN` | bootstrap Step Summary の `terraform_apply_role_arn`（prod） |

`dev` / `stg` / `prod` 全環境に Required reviewers を設定します（後述）。

---

### Step 2: コードを develop ブランチに push する

```bash
git checkout -b develop
git add .
git commit -m "initial commit"
git push -u origin develop
```

> GitHub リポジトリの default branch を `develop` に設定してください。
> `Settings → Branches → Default branch`

---

### Step 3: CODEOWNERS を設定する

現在は個人アカウント（`@yusa0730`）で設定済みです。

```
/environments/      @yusa0730
/modules/           @yusa0730
/.github/workflows/ @yusa0730
/.github/CODEOWNERS @yusa0730
```

#### Team 運用への移行（Organization がある場合）

複数人でレビューを運用する際は、個人ユーザーの代わりに GitHub Team を指定します。

**Team の作成手順**

```
1. github.com/<your-org> → Teams → New team
     Team name: infra-approvers
     Visibility: Visible（← CODEOWNERS 参照に必須）

2. Teams → infra-approvers → Members → Add a member
     → レビュアーを追加

3. Teams → infra-approvers → Repositories → Add repository
     → このリポジトリを追加
     → Role: Write（← CODEOWNERS 機能に必須）
```

**CODEOWNERS の書き換え**

```
/environments/      @your-org/infra-approvers
/modules/           @your-org/infra-approvers
/.github/workflows/ @your-org/infra-approvers
/.github/CODEOWNERS @your-org/infra-approvers
```

> `@your-org` は Organization 名、`infra-approvers` は Team 名に置き換えてください。

---

### Step 4: Branch Protection Rules を設定する

`Settings → Branches → Add branch ruleset` で `develop` / `stg` / `prod` それぞれに設定します。

| 項目 | 値 |
|-----|---|
| Require a pull request before merging | ✅ |
| Require approvals | ✅（1 以上） |
| Require review from Code Owners | ✅ |
| Require status checks to pass before merging | ✅ |
| Required status checks | `terraform-plan / required` |

---

### Step 5: 動作確認

```
1. feature ブランチを作成して develop へ PR を出す
   → terraform-plan が自動実行される
   → PR コメントに plan 結果が tfcmt 形式で表示される
     （削除がある場合は WARNING ラベルと警告コメントが付く）
   → conftest でセキュリティポリシーチェックが実行される

2. CODEOWNERS (infra-approvers) が approve → develop へ merge する
   → terraform-apply が自動実行される
   → apply workflow 内で terraform plan -out=tfplan を作成し、
     直後に terraform apply tfplan を実行する
   → dev 環境に apply される

3. develop → stg へ PR を出して merge する
   → stg 環境に apply される

4. stg → prod へ PR を出して merge する
   → prod-plan が自動実行される（conftest チェック + Step Summary に plan 全文）
   → 承認者が内容を確認して「Approve and deploy」をクリックする
   → prod-apply で保存済み tfplan を apply する
   → prod 環境に apply される
```

> `terraform-apply.yml` での tfplan は apply workflow 内で新規に作成します。
> PR 時の `terraform-plan.yml` で作成した tfplan を再利用しているわけではありません。

---

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [アーキテクチャ](docs/architecture.md) | AWS 構成・ネットワーク・ECS・RDS・IAM の詳細 |
| [CI/CD](docs/cicd.md) | Workflows 一覧・Secrets 一覧・destroy 手順 |
