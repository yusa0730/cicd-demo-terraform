# CI/CD リファレンス

## Workflows 一覧

### terraform-repo（このリポジトリ）

| ファイル | トリガー | 内容 |
|---------|---------|------|
| `terraform-plan.yml` | PR（develop / stg / prod 向け） | fmt チェック・plan を実行。tfcmt で PR コメント通知（削除があれば警告ラベル付き）、conftest でセキュリティポリシーチェック |
| `terraform-apply.yml` | PR マージ（develop / stg / prod） | マージされた PR をトリガーに apply を実行。dev / prod は plan → artifact → 承認ゲート → apply。stg は plan + apply を同一 job で実行 |
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

### stg（軽量運用）

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

> **stg の位置づけ:** stg は現時点では dev / prod と同じ artifact + 承認ゲートフローは適用せず、軽量な plan-then-apply を維持します。stg を本番前の厳密な最終検証環境として運用する段階になった場合は、dev / prod と同じフローへ移行します。

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

---

## state 分離後の workflow 変更点

state を `base` / `data` / `app` に分割した後は、plan / apply / destroy の単位も stack ごとになります。

### PR plan（terraform-plan.yml）

```
PR を作成 / 更新
  ↓
変更された stack（base / data / app）を検出
  ↓
各 stack で独立して plan を実行
  ↓
required job で全 stack の成否を集約
```

### apply（terraform-apply.yml）

apply は依存順序に従い、stack ごとに順番に実行します。

```
PR マージ（develop / stg / prod）
  ↓
base-plan → [承認] → base-apply
  ↓
data-plan → [承認] → data-apply
  ↓
app-plan  → [承認] → app-apply
```

### destroy（terraform-destroy.yml）

destroy は apply の逆順で実行します。

```
app-destroy  → [承認] → 実行
  ↓
data-destroy → [承認] → 実行
  ↓
base-destroy → [承認] → 実行
```

> 依存関係があるため、app を消す前に data / base を消すと参照エラーになります。
> 必ず逆順で実行してください。

---

## Slack 通知

### 概要

[slackapi/slack-github-action](https://github.com/slackapi/slack-github-action) v3 の `chat.postMessage` を使い、Terraform CI/CD の重要イベントを Slack へ通知します。通知先は 1 チャンネルに集約し、メッセージ内の種別・環境・結果で識別します。

### 通知先・Secrets

| Secret 名 | 用途 | 設定場所 |
|---|---|---|
| `SLACK_BOT_TOKEN` | Slack Bot Token（`xoxb-...`） | Repository Secrets |
| `SLACK_CHANNEL_ID_TERRAFORM` | 通知先チャンネル ID | Repository Secrets |

通知先チャンネル: `#all-terraform-notification-test`

> チャンネル ID は Slack のチャンネル詳細画面の下部に表示される `C` で始まる文字列です（チャンネル名 `#...` ではありません）。

> Slack Bot は通知先チャンネルに参加している必要があります（`/invite @ボット名`）。

### 通知一覧

| 種別 | アイコン | トリガー | 実装箇所 |
|---|---|---|---|
| apply 成功 | ✅ | dev-apply / prod-apply 完了 | `terraform-apply.yml` |
| apply 失敗 | ❌ | dev-apply / prod-apply 失敗 | 同上（`if: always()` で必ず送信） |
| plan 失敗 | ❌ | PR の terraform-plan が失敗 | `terraform-plan.yml`（`notify-plan-failure` job） |
| destructive changes | ⚠️ | plan に delete / replace が含まれる | `terraform-apply.yml` dev-plan / prod-plan |
| destroy plan 作成 | 🚨 | destroy-plan 完了・承認待ち開始 | `terraform-destroy.yml` destroy-plan |
| destroy 成功/失敗 | 🚨 | terraform-destroy 完了 | `terraform-destroy.yml` destroy-apply |

> stg の apply 通知は現時点では対象外です（stg は軽量運用を維持）。

### 通知メッセージの内容

各通知には以下の情報を含みます。

| フィールド | 内容 |
|---|---|
| 種別・結果 | アイコン + タイトル（例: ✅ *Terraform apply success*） |
| Environment | `dev` / `stg` / `prod` |
| Repository | リポジトリ名 |
| Branch / PR | ブランチ名または PR リンク |
| Actor | 実行者の GitHub ユーザー名 |
| Run | GitHub Actions の実行ログへのリンク |

destructive changes 通知には delete / replace のリソース数も含みます。

destroy-plan 通知は「承認待ち開始」のタイミングで送信されるため、承認者が destroy を認識して Actions 画面へアクセスするきっかけになります。

### 実装上のポイント

**`if: always()` で失敗時も通知する**

apply / destroy の通知ステップは `if: always()` を設定しています。前段の terraform apply が失敗しても通知ステップが必ず実行されるため、失敗を見逃しません。

```yaml
- name: Notify Slack apply result
  if: always()
  continue-on-error: true
```

**`continue-on-error: true` で通知失敗を無害化する**

Slack API の一時的な障害や Secret の未設定が原因で通知ステップが失敗しても、workflow 全体への影響を防ぎます。

**`unfurl_links: false` でリンクカード展開を抑制する**

GitHub Actions の URL を貼るとリンクカードが展開されて通知が大きくなるため、全通知に `unfurl_links: false` / `unfurl_media: false` を設定しています。

**destructive detection の順序（dev / prod 共通）**

```
terraform plan -out=tfplan
  ↓
terraform show -json tfplan > tfplan.json
destructive detection（delete / replace 件数をカウント）
  ↓
Slack 警告通知（delete / replace が 1 件以上の場合）
  ↓
conftest セキュリティチェック
  ↓
Step Summary 表示
  ↓
artifact upload
```

destructive detection を conftest より先に実行することで、conftest が失敗した場合でも「削除・置換を含む危険な plan だった」という事実を Slack に残せます。

**destructive changes の検知ロジック**

```bash
DELETE_COUNT=$(jq '[.resource_changes[]? | select(.change.actions == ["delete"])] | length' tfplan.json)
REPLACE_COUNT=$(jq '[.resource_changes[]? | select(.change.actions == ["delete","create"] or .change.actions == ["create","delete"])] | length' tfplan.json)
```

1 件以上あれば `has_destructive_changes=true` を出力し、後続の通知ステップが起動します。

### Slack App のセットアップ手順

1. [api.slack.com/apps](https://api.slack.com/apps) でアプリを作成
2. **OAuth & Permissions** → **Bot Token Scopes** に `chat:write` を追加
3. **Install to Workspace** でインストール → **Bot User OAuth Token**（`xoxb-...`）をコピー
4. 通知先チャンネルで `/invite @ボット名` を実行
5. GitHub Repository Secrets に以下を登録

```
SLACK_BOT_TOKEN             = xoxb-...
SLACK_CHANNEL_ID_TERRAFORM  = C0XXXXXXXXX
```

### 疎通確認

`slack-test.yml` workflow を使って、本番 workflow に組み込む前に Slack への接続を確認できます。

```
GitHub → Actions → slack-test → Run workflow
```
