# CI/CD セットアップガイド

## Workflows

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `bootstrap.yml` | 手動（`workflow_dispatch`） | 選択した環境の S3 バケット作成・IAM Role 作成。初回のみ実行 |
| `terraform-plan.yml` | PR（develop / stg / prod 向け） | fmt チェック・validate・plan を実行し結果を PR コメントに投稿 |
| `terraform-apply.yml` | push（develop / stg / prod） | plan → apply を実行。prod のみ plan 確認後に承認ゲートを挟む |
| `terraform-destroy.yml` | 手動（`workflow_dispatch`） | 選択した環境のリソースを destroy。`destroy` と入力して確認後に実行 |

---

## セットアップ手順

### 前提条件

- GitHub リポジトリが作成済みであること
- AWS アカウントへのアクセス権があること（初回のみ IAM ユーザー作成が必要）

---

### Step 1: 一時 IAM ユーザーを作成（AWS Console）

bootstrap workflow 実行のため、一時的な IAM ユーザーを作成します。

1. `IAM → Users → Create user` でユーザーを作成
   - ユーザー名: `github-bootstrap`（任意）
   - 権限: `AdministratorAccess`
2. アクセスキーを発行し、`Access key ID` と `Secret access key` を控える

> bootstrap 完了後にこのユーザーは削除します。

---

### Step 2: GitHub に一時 credentials を登録

`Settings → Secrets and variables → Actions → New repository secret`

| Secret 名 | 値 |
|-----------|---|
| `AWS_BOOTSTRAP_ACCESS_KEY_ID` | 手順 1 の Access key ID |
| `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | 手順 1 の Secret access key |

---

### Step 3: コードを push して bootstrap を実行

```bash
git checkout -b develop
git add .
git commit -m "initial commit"
git push -u origin develop
```

`Actions → bootstrap → Run workflow` で `target_environment = dev` を選択して実行します。

> stg / prod を追加するときも同じ workflow を `target_environment = stg` / `prod` で実行します。
> **dev を必ず最初に実行してください**（GitHub OIDC Provider を dev が作成し、stg / prod はそれを参照します）。

---

### Step 4: Step Summary の ARN を GitHub に登録

bootstrap 完了後、Step Summary に以下が表示されます。

#### Repository Secrets（`Settings → Secrets and variables → Actions`）

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | Step Summary の値 |

#### GitHub Environment `dev`（`Settings → Environments → New environment`）

| Secret 名 | 値 |
|-----------|---|
| `AWS_TERRAFORM_ROLE_ARN` | Step Summary の値 |

#### app-repo の GitHub Environment `dev`

| Secret 名 | 値 |
|-----------|---|
| `AWS_DEPLOY_ROLE_ARN` | Step Summary の値 |

---

### Step 5: 一時 credentials を削除

- GitHub の Repository Secrets から `AWS_BOOTSTRAP_ACCESS_KEY_ID` / `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` を削除
- AWS Console で `github-bootstrap` IAM ユーザーを削除

---

### Step 6: Branch Protection Rules を設定

`Settings → Branches → Add branch ruleset` で `develop` / `stg` / `prod` それぞれに設定します。

| 項目 | 値 |
|-----|---|
| Require a pull request before merging | ✅ |
| Require approvals | ✅ (1 以上) |
| Require review from Code Owners | ✅ |
| Require status checks to pass before merging | ✅ |
| Required status checks | `terraform-plan / fmt`, `terraform-plan / plan` |

`prod` Environment には Required reviewers も設定します。

---

### Step 7: 動作確認

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
> GitHub Environment の Required reviewers を設定しておくと、destroy-plan の内容を確認してから承認できます。

---

## Secrets / Variables 一覧

### Repository Secrets

| 名前 | 用途 |
|-----|-----|
| `AWS_BOOTSTRAP_ACCESS_KEY_ID` | bootstrap 実行用（bootstrap 完了後に削除） |
| `AWS_BOOTSTRAP_SECRET_ACCESS_KEY` | bootstrap 実行用（bootstrap 完了後に削除） |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_DEV` | dev plan / destroy-plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_STG` | stg plan / destroy-plan 用 IAM Role ARN |
| `AWS_TERRAFORM_PLAN_ROLE_ARN_PROD` | prod plan / destroy-plan 用 IAM Role ARN |

### Repository Variables（任意）

| 名前 | デフォルト値 | 用途 |
|-----|------------|-----|
| `AWS_REGION` | `ap-northeast-1` | AWS リージョン |

### Environment Secrets（各 Environment に設定）

| 名前 | 用途 |
|-----|-----|
| `AWS_TERRAFORM_ROLE_ARN` | apply / destroy-apply 用 IAM Role ARN（Environment ごとに別の ARN） |
