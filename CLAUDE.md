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

## ディレクトリ構成

```
environments/<env>/   # 環境ルートモジュール（dev / stg / prod）
modules/              # 共有モジュール
  alb/
  database/
  ecr/
  ecs_app/
  kms/
  network/
policy/               # conftest OPAポリシー
.checkov.yml          # Checkov skip設定（理由付きのみ許可）
```

## Terraform コーディング規約

### variable ブロックの書き方

`variable` ブロックには必ず `description` と `type` を記述する。

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

記述順: `description` → `type` → `default`（`default` がある場合）

### `=` 記号の整列（terraform fmt 準拠）

`terraform fmt` のルールに従い、同一ブロック内の `=` を最長キーに揃える。
`jsonencode` 内の Statement ブロックも同様に揃える（`Sid`, `Effect`, `Action`, `Resource`）。

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

## 変更時に必ず確認すること

**Terraform 変更時:**
1. `terraform fmt -recursive`
2. `terraform validate`
3. `terraform plan`（`tfcmt` 経由）
4. `conftest test tfplan.json -p policy/`
5. `trivy config --tf-vars environments/<env>/terraform.tfvars environments/<env>`
6. `checkov -d environments/<env> --framework terraform --config-file .checkov.yml`

**GitHub Actions 変更時:**
- OIDC `sub` 条件と workflow trigger が一致しているか
- Repository Secrets と Environment Secrets の使い分けが正しいか
- Required checks 名が Branch Protection と一致するか

**Security scan skip 追加時:**
- skip 理由をコメントまたは `.checkov.yml` に必ず残す
- dev 限定の例外か prod にも適用されるかを明記する
- 沈黙 skip 禁止

## 禁止事項

- `environments/<env>` に GitHub OIDC Provider を追加しない
- `environments/<env>` に Terraform 実行 Role を追加しない
- AWS access key を Terraform コードや README に書かない
- `terraform state` を手動編集しない
- CI を通すためだけに理由なしで Checkov / Trivy を skip しない
- `continue-on-error: true` でセキュリティ scan を握りつぶさない
- `terraform apply` / `terraform destroy` をこのセッション内で直接実行しない
