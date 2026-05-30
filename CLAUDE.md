# cicd-demo-terraform

このリポジトリは ECS on Fargate + RDS + ALB のアプリケーション実行基盤を管理する Terraform repository。

## 責務

**このrepoで管理する:**
- VPC / Subnet / NAT Gateway / Internet Gateway
- ALB (Listener, Target Group, Security Group)
- ECS (Cluster, Service, Task Definition)
- ECR Repository
- RDS (PostgreSQL, Security Group)
- KMS Key
- SSM Parameter Store
- Secrets Manager
- CloudWatch Log Group

**このrepoで管理しない:**
- GitHub OIDC Provider
- Terraform plan/apply IAM Role
- App deploy IAM Role
- AWS account baseline (GuardDuty, CloudTrail, Config, Security Hub)
- AWS Organizations / account vending

上記は別repoで管理する:
- `cicd-demo-terraform-bootstrap` → OIDC / IAM Role
- `cicd-demo-terraform-accounts` → Account baseline

## backend repo との責務分離

- DB migration は `cicd-demo-backend` の CD で ECS one-off task として実行する
- このrepoは migration に必要な ECS Task Definition / IAM / network / Secrets / SSM 出力を提供するだけ
- **Terraform apply 内で DB migration を実行しない**
- `local-exec` / `remote-exec` で migration やシェルコマンドを実行しない

## ディレクトリ構成

```
environments/<env>/
  base/   # KMS / VPC / Subnet / NAT Gateway / VPC Endpoint / Flow Logs
  data/   # RDS / DB Subnet Group / Secrets Manager
  app/    # ALB / ECS / ECR / SSM Parameters / SG rules
modules/  # 共有モジュール
  alb/
  database/
  ecr/
  ecs_app/
  kms/
  network/
policy/   # conftest OPAポリシー
.checkov.yml  # Checkov skip設定（理由付きのみ許可）
```

> `environments/<env>/` 直下の単一 state（legacy）は移行完了後に廃止する。

## State 分離方針

- `base` → `data` → `app` の順で依存する（apply 順序も同じ）
- destroy は逆順で `app` → `data` → `base`
- state 間の値受け渡しは `terraform_remote_state` を使う
- **secret 値そのものを Terraform output に出さない**（state にアクセスできる権限者が読めるため）
- `data` は RDS など stateful resource を含むため、変更時は特に慎重に plan を確認する

## Terraform State Backend 方針

- state backend は S3 を使う
- `use_lockfile = true` を必ず有効にする（S3 ネイティブロック）
- state key の形式は `ecs-demo/<env>/<stack>/terraform.tfstate` に統一する
  - 例: `ecs-demo/dev/base/terraform.tfstate`
  - 例: `ecs-demo/dev/data/terraform.tfstate`
  - 例: `ecs-demo/dev/app/terraform.tfstate`
- Terraform 実行 Role には対象 key と `.tflock` への S3 権限を付与する
- S3 bucket versioning は有効化する（誤削除・人的ミスからの復旧に必須）

## 重要な設計判断

- dev / stg / prod は別 AWS アカウント前提
- `environments/<env>` を destroy しても `terraform-bootstrap` 側の IAM Role / OIDC Provider は削除されない設計を維持する
- container_port はモジュールのデフォルト(3000)に合わせ、環境 locals で管理する
- SSM Parameter は SecureString + CMK、ECR/CloudWatch Logs は KMS 暗号化
- SG egress はモジュール側に書かず、環境レベルで `aws_vpc_security_group_egress_rule` を使って絞り込む

## CI/CD ルール

- Terraform plan は PR で実行する（`terraform-plan` workflow）
- Terraform apply は PR merge 後に実行する（`terraform-apply` workflow）
- prod apply / destroy は GitHub Environment approval 必須
- security scan (Trivy + Checkov) は必須ゲート（`continue-on-error` で逃がさない）

## Terraform コーディング規約

### variable ブロックの書き方

`variable` ブロックには必ず `description` と `type` を記述する。

記述順: `description` → `type` → `default`（`default` がある場合）

```hcl
# 良い例
variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
}

variable "desired_count" {
  description = "ECS サービスの希望タスク数"
  type        = number
  default     = 1
}

# 悪い例（description / type が欠けている）
variable "vpc_cidr" {}
variable "desired_count" {
  default = 1
}
```

### `=` 記号の整列（terraform fmt 準拠）

`terraform fmt` のルールに従い、同一ブロック内の `=` を最長キーに揃える。
`jsonencode` 内の Statement ブロックも同様に揃える（`Sid`, `Effect`, `Action`, `Resource`）。

### Provisioner 方針

- `local-exec` / `remote-exec` は原則禁止
- DB migration、ECS deploy、外部コマンド実行を Terraform provisioner で行わない
- 必要な場合は理由を PR に明記し、conftest policy の変更もセットでレビューする

## 変更時に必ず確認すること

**Terraform 変更時（state 分離後は `<stack>` = base / data / app）:**

```bash
terraform fmt -recursive
terraform -chdir=environments/<env>/<stack> init
terraform -chdir=environments/<env>/<stack> validate
terraform -chdir=environments/<env>/<stack> plan -var-file=terraform.tfvars -out=tfplan
terraform -chdir=environments/<env>/<stack> show -json tfplan > tfplan.json
conftest test tfplan.json -p policy/
trivy config --tf-vars environments/<env>/<stack>/terraform.tfvars environments/<env>/<stack>
checkov -d environments/<env>/<stack> --framework terraform --config-file .checkov.yml
```

**GitHub Actions 変更時:**
- OIDC `sub` 条件と workflow trigger が一致しているか
- Repository Secrets と Environment Secrets の使い分けが正しいか
- Required check 名が Branch Protection と一致するか
- Required check は原則 `terraform-plan / required` のみを指定する（reusable workflow 内部の job 名を直接指定しない）
- workflow 変更後は、対象 check が直近 7 日以内に成功していて GitHub UI 上で選択できることを確認する

**Security scan skip 追加時:**
- skip 理由をコメントまたは `.checkov.yml` に必ず残す
- dev 限定の例外か prod にも適用されるかを明記する
- 沈黙 skip 禁止

## 禁止事項

- `environments/<env>` に GitHub OIDC Provider を追加しない
- `environments/<env>` に Terraform 実行 Role を追加しない
- AWS access key を Terraform コードや README に書かない
- `terraform.tfstate` ファイルを直接編集しない
- `terraform state mv` / `state pull` / `state push` は state 分離作業として明示された手順がある場合のみ実行する（実行前に必ず `terraform state pull` でバックアップを取得し、移行後は `terraform plan` で意図しない add / destroy / replace がないことを確認する）
- CI を通すためだけに理由なしで Checkov / Trivy を skip しない
- `continue-on-error: true` でセキュリティ scan を握りつぶさない
- Claude Code は `terraform apply` / `terraform destroy` を直接実行しない。apply / destroy は GitHub Actions workflow 経由で実行する。ローカルでの `terraform plan` は許可するが、実リソースを変更する操作は提案に留める
