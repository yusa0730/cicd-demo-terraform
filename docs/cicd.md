# CI/CD リファレンス

## Workflows 一覧

### terraform-repo（このリポジトリ）

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `terraform-plan.yml` | PR（develop / stg / prod 向け） | fmt チェック・plan を実行。tfcmt で PR コメント通知（削除があれば警告ラベル付き）、conftest でセキュリティポリシーチェック |
| `terraform-apply.yml` | PR マージ（develop / stg / prod） | マージされた PR をトリガーに apply を実行。prod のみ plan 確認後に承認ゲートを挟む |
| `terraform-destroy.yml` | 手動（`workflow_dispatch`） | 選択した環境のリソースを destroy。dev/stg: `destroy`、prod: `destroy-prod` と入力して確認後に実行 |
| `_reusable-terraform-plan.yml` | `workflow_call` | PR plan の共通実装（terraform-plan.yml から呼び出し） |
| `_reusable-terraform-apply.yml` | `workflow_call` | dev/stg apply の共通実装（terraform-apply.yml から呼び出し） |

### terraform-bootstrap（別リポジトリ）

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `bootstrap.yml` | 手動（`workflow_dispatch`） | S3 バケット作成・GitHub OIDC Provider 作成・IAM Role 作成。初回および IAM 変更時に実行 |
| `bootstrap-fmt.yml` | PR（main 向け） | terraform fmt チェック |

### terraform-accounts（別リポジトリ）

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `baseline-plan.yml` | PR（develop / stg / prod 向け） | fmt チェック・plan を実行。tfcmt で PR コメント通知 |
| `baseline-apply.yml` | PR マージ（develop / stg / prod） | アカウントセキュリティベースラインを適用。prod は承認ゲートあり |
| `_reusable-baseline-plan.yml` | `workflow_call` | baseline plan の共通実装 |
| `_reusable-baseline-apply.yml` | `workflow_call` | baseline apply の共通実装 |

## Terraform CI セキュリティ制御

### tfcmt による plan 通知

[tfcmt](https://github.com/suzuki-shunsuke/tfcmt) を使用して plan 結果を PR にコメントします。

- リソースの削除が含まれる場合は `terraform:destroy` ラベルと WARNING コメントを付与
- 変更がある場合は `terraform:changed` ラベルを付与

設定ファイル: `.tfcmt.yml`

### conftest による静的チェック

[conftest](https://github.com/open-policy-agent/conftest) + OPA (Open Policy Agent) で Terraform plan JSON を検査します。

- `local-exec` provisioner の使用を禁止
- `remote-exec` provisioner の使用を禁止

ポリシーファイル: `policy/terraform.rego`

terraform-plan.yml（PR plan）と terraform-apply.yml（prod-plan）の両方で実行します。

### secret exfiltration 対策

- `pull_request_target` は使用しない（fork PR からの secret 漏洩を防ぐため）
- plan role / apply role を分離し、apply 権限は Environment approval 後のみ使用
- Secrets Manager の値を terraform output に出力しない

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
- Branch Protection Rules では `terraform-plan / required` 1つだけを Required check として登録します
- `required` ジョブが `fmt` と `plan` の両方の成否を集約するため、reusable workflow による
  check 名の階層化（`terraform-plan / plan / plan` のような形）に影響されません

---

## terraform-apply の動作

### dev / prod（同じフロー）

```
PR マージ（develop / prod ブランチへ）
  ↓
dev-plan / prod-plan
  └─ conftest セキュリティチェック
  └─ plan 結果を Step Summary に表示
  └─ tfplan を artifact として保存
  ↓
[GitHub Environment の Required reviewers が内容を確認して承認]
  ↓
dev-apply / prod-apply（保存済み tfplan を apply）
```

- `pull_request: types: [closed]` + `merged == true` でトリガーします
- plan と apply は別 job として実行されます
- plan は plan 専用 IAM Role（`AWS_TERRAFORM_PLAN_ROLE_ARN_*`）で実行します
- apply は Environment Secret の apply 専用 IAM Role（`AWS_TERRAFORM_ROLE_ARN`）で実行します
- 承認者は Step Summary の plan 内容を確認してから承認できます
- 承認された apply は plan 時に保存した artifact（tfplan）をそのまま適用するため、承認後に内容が変わりません

### stg

```
PR マージ（stg ブランチへ）
  ↓
plan（terraform plan -out=tfplan）
  ↓
apply（terraform apply tfplan）
```

- apply workflow 内で tfplan を新規作成し、直後に apply します
- PR 時の `terraform-plan.yml` で作成した tfplan を再利用しているわけではありません
- `environment: stg` によって Required reviewers の承認ゲートが apply 開始前に入ります

---

## 環境の削除（terraform-destroy）

デモ終了後など、不要になった環境を削除する場合は `terraform-destroy` workflow を使います。

`Actions → terraform-destroy → Run workflow`

| 入力項目 | 説明 |
|---------|------|
| `target_environment` | 削除対象の環境（dev / stg / prod） |
| `confirm` | dev/stg は `destroy`、prod は `destroy-prod` と入力して実行を確定する |

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

## GitHub Environment の保護設定

### Required reviewers

全環境のapply / destroyに**必須承認者**を設定しています。

**設定場所:**
```
リポジトリ → Settings → Environments → [環境名] → Environment protection rules
→ Required reviewers
```

**現在の設定:**

| リポジトリ | Environment | Required reviewers |
|---|---|---|
| terraform-repo | `dev` | `yusa0730` |
| terraform-repo | `stg` | `yusa0730` |
| terraform-repo | `prod` | `yusa0730` |
| app-repo | `dev` | `yusa0730` |
| app-repo | `stg` | `yusa0730` |
| app-repo | `prod` | `yusa0730` |

**どのように機能するか:**

workflow の `environment:` にEnvironment名を指定したジョブは、実行開始前に
承認者の手動承認を要求します。承認されるまでジョブは `waiting` 状態で停止します。

```
terraform apply / ECS deploy の起動
    ↓
GitHub が Required reviewers へ承認通知
    ↓
承認者が Actions 画面で「Review deployments」→「Approve and deploy」
    ↓
apply / deploy ジョブが実行される
```

> この設定は `.github/workflows/*.yml` には書けません。
> Settings 画面または GitHub REST API で設定します。

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

### terraform-bootstrap の GitHub Environments（初回のみ）

bootstrap 実行時のみ使用します。apply 完了後は削除します。

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
