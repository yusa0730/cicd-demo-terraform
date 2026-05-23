# terraform-repo

ECS on Fargate + RDS + ALB 構成を Terraform で管理する CI/CD デモリポジトリです。

## はじめに

このリポジトリを初めて使うときは、以下の手順で環境を構築してください。

---

### Step 1: AWS に bootstrap 用 IAM ユーザーを作成する

GitHub Actions が初回のみ AWS を操作するために、一時的な IAM ユーザーを作成します。

1. AWS Console → `IAM → Users → Create user`
   - ユーザー名: `github-bootstrap`（任意）
   - 権限: `AdministratorAccess`
2. アクセスキーを発行して `Access key ID` と `Secret access key` を控える

> bootstrap 完了後にこのユーザーは削除します。

---

### Step 2: GitHub に Bootstrap Environment を作成する

bootstrap 用の認証情報を、GitHub の Environment に登録します。
Repository Secrets ではなく **Environment Secrets** を使う理由は、環境ごとに別の AWS アカウントの認証情報を分けて管理するためです。

`Settings → Environments → New environment` で以下の 3 つを作成します。

| Environment 名 | 対象 AWS アカウント |
|---------------|-----------------|
| `bootstrap-dev` | dev 用 AWS アカウント |
| `bootstrap-stg` | stg 用 AWS アカウント |
| `bootstrap-prod` | prod 用 AWS アカウント |

各 Environment に以下の Secret を登録します。

| Secret 名 | 値 |
|-----------|---|
| `AWS_BOOTSTRAP_ACCESS_KEY_ID` | Step 1 の Access key ID |
| `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | Step 1 の Secret access key |

---

### Step 3: コードを develop ブランチに push する

```bash
git checkout -b develop
git add .
git commit -m "initial commit"
git push -u origin develop
```

> GitHub リポジトリの default branch を `develop` に設定してください。
> `Settings → Branches → Default branch`
> （`workflow_dispatch` は default branch のワークフローしか実行できないためです）

---

### Step 4: bootstrap を実行する（dev から順番に）

`Actions → bootstrap → Run workflow` を開き、`target_environment = dev` を選択して実行します。

bootstrap が行うこと：
- S3 state バケット（`cicd-demo-terraform-dev`）を AWS CLI で作成
- GitHub OIDC Provider を AWS IAM に作成
- Terraform plan 用・apply 用・app deploy 用の IAM Role を作成

> **dev を必ず最初に実行してください。**
> stg / prod は後から同じ手順で実行します（`target_environment = stg` / `prod`）。

---

### Step 5: Step Summary の ARN を GitHub に登録する

bootstrap 完了後、Step Summary に 3 つの Role ARN が表示されます。
以下の場所に登録してください。

#### terraform-repo の Repository Secrets

`Settings → Secrets and variables → Actions → Repository secrets`

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | Step Summary の `terraform_plan_role_arn` |

#### terraform-repo の GitHub Environment `dev`

`Settings → Environments → dev`

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_ROLE_ARN` | Step Summary の `terraform_apply_role_arn` |

#### app-repo の GitHub Environment `dev`

| Secret 名 | 値 |
|-----------|---|
| `AWS_DEPLOY_ROLE_ARN` | Step Summary の `app_deploy_role_arn` |

---

### Step 6: bootstrap 用の認証情報を削除する

GitHub の `bootstrap-dev` Environment から以下を削除します。

- `AWS_BOOTSTRAP_ACCESS_KEY_ID`
- `AWS_BOOTSTRAP_SECRET_ACCESS_KEY`

AWS Console で `github-bootstrap` IAM ユーザーを削除します。

---

### Step 7: Branch Protection Rules を設定する

`Settings → Branches → Add branch ruleset` で `develop` / `stg` / `prod` それぞれに設定します。

| 項目 | 値 |
|-----|---|
| Require a pull request before merging | ✅ |
| Require approvals | ✅（1 以上） |
| Require review from Code Owners | ✅ |
| Require status checks to pass before merging | ✅ |
| Required status checks | `terraform-plan / fmt`、`terraform-plan / plan` |

`prod` Environment には Required reviewers も設定します（apply 前に承認が必要なため）。

---

### Step 8: stg / prod の bootstrap も実行する

Step 4〜6 を `target_environment = stg`、`target_environment = prod` で繰り返します。

---

### Step 9: 動作確認

```
1. feature ブランチを作成して develop へ PR を出す
   → terraform-plan が自動実行される
   → PR コメントに plan の結果が表示される

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

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [アーキテクチャ](docs/architecture.md) | AWS 構成・ネットワーク・ECS・RDS・IAM の詳細 |
| [CI/CD](docs/cicd.md) | Workflows 一覧・Secrets 一覧・destroy 手順 |
