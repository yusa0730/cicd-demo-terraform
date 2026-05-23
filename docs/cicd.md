# CI/CD リファレンス

## Workflows 一覧

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `bootstrap.yml` | 手動（`workflow_dispatch`） | 選択した環境の S3 バケット作成・GitHub OIDC Provider 作成・IAM Role 作成。初回のみ実行 |
| `terraform-plan.yml` | PR（develop / stg / prod 向け） | fmt チェック・plan を実行し結果を PR コメントに投稿 |
| `terraform-apply.yml` | PR マージ（develop / stg / prod） | マージされた PR をトリガーに apply を実行。prod のみ plan 確認後に承認ゲートを挟む |
| `terraform-destroy.yml` | 手動（`workflow_dispatch`） | 選択した環境のリソースを destroy。`destroy` と入力して確認後に実行 |

---

## terraform-plan の動作

```
PR を作成 / 更新
  ↓
fmt（terraform fmt -check -recursive）
  ↓
plan（terraform plan -out=tfplan）
  ↓
PR コメントに plan 結果を投稿（upsert）
```

- `fmt` と `plan` は並列実行ではなく別 job として実行されます
- PR コメントは `<!-- terraform-plan-{env} -->` マーカーで upsert します（同一 PR に複数回 push してもコメントが増えません）
- `fmt` / `plan` の両 status checks が通過しないとマージできません（Branch Protection Rules）

---

## terraform-apply の動作

### dev / stg

```
PR マージ（develop / stg ブランチへ）
  ↓
apply（terraform apply tfplan）
```

- `pull_request: types: [closed]` + `merged == true` でトリガーします
- plan 済みの tfplan を apply するため、apply 時に追加変更が入りません

### prod

```
PR マージ（prod ブランチへ）
  ↓
prod-plan（terraform plan 結果を Step Summary に表示）
  ↓
[GitHub Environment `prod` の Required reviewers が内容を確認して承認]
  ↓
prod-apply（terraform apply）
```

---

## 環境の削除（terraform-destroy）

デモ終了後など、不要になった環境を削除する場合は `terraform-destroy` workflow を使います。

`Actions → terraform-destroy → Run workflow`

| 入力項目 | 説明 |
|---------|------|
| `target_environment` | 削除対象の環境（dev / stg / prod） |
| `confirm` | `destroy` と入力して実行を確定する |

### 実行フロー

```
入力確認（"destroy" と入力されているか検証）
  ↓
destroy-plan（terraform plan -destroy でリソース削除内容を Step Summary に表示）
  ↓
[GitHub Environment の Required reviewers によって承認待ち]
  ↓
destroy-apply（保存済み destroy plan を apply）
```

> **注意**: destroy は不可逆な操作です。RDS などのデータが削除されます。

---

## Secrets / Variables 一覧

### terraform-repo の Repository Secrets

| 名前 | 用途 |
|-----|-----|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | dev の plan / destroy-plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | stg の plan / destroy-plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | prod の plan / destroy-plan 用 IAM Role ARN |

### terraform-repo の GitHub Environments

`Settings → Environments` で `dev` / `stg` / `prod` を作成します。

| Environment 名 | Secret 名 | 用途 |
|--------------|-----------|------|
| `dev` | `AWS_TERRAFORM_ROLE_ARN` | dev の apply / destroy-apply 用 IAM Role ARN |
| `stg` | `AWS_TERRAFORM_ROLE_ARN` | stg の apply / destroy-apply 用 IAM Role ARN |
| `prod` | `AWS_TERRAFORM_ROLE_ARN` | prod の apply / destroy-apply 用 IAM Role ARN |

### terraform-repo の bootstrap Environments（初回のみ）

bootstrap 実行時のみ使用します。bootstrap 完了後は削除します。

| Environment 名 | Secret 名 | 用途 |
|--------------|-----------|------|
| `bootstrap-dev` | `AWS_BOOTSTRAP_ACCESS_KEY_ID` | dev アカウントの bootstrap 用一時 IAM User |
| `bootstrap-dev` | `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | dev アカウントの bootstrap 用一時 IAM User |
| `bootstrap-stg` | `AWS_BOOTSTRAP_ACCESS_KEY_ID` | stg アカウントの bootstrap 用一時 IAM User |
| `bootstrap-stg` | `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | stg アカウントの bootstrap 用一時 IAM User |
| `bootstrap-prod` | `AWS_BOOTSTRAP_ACCESS_KEY_ID` | prod アカウントの bootstrap 用一時 IAM User |
| `bootstrap-prod` | `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | prod アカウントの bootstrap 用一時 IAM User |

### app-repo の GitHub Environments

| Environment 名 | Secret 名 | 用途 |
|--------------|-----------|------|
| `dev` | `AWS_DEPLOY_ROLE_ARN` | dev の ECR push / ECS deploy 用 IAM Role ARN |
| `stg` | `AWS_DEPLOY_ROLE_ARN` | stg の ECR push / ECS deploy 用 IAM Role ARN |
| `prod` | `AWS_DEPLOY_ROLE_ARN` | prod の ECR push / ECS deploy 用 IAM Role ARN |

### Repository Variables（任意）

| 名前 | デフォルト値 | 用途 |
|-----|------------|-----|
| `AWS_REGION` | `ap-northeast-1` | AWS リージョン |
