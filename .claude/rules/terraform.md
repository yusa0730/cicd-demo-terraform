---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
---

# Terraform Rules

## variable ブロックの書き方

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

## フォーマット

- `terraform fmt -recursive` に従う
- `jsonencode` 内の `Sid`, `Effect`, `Action`, `Resource` も最長キーに揃える

## Provisioner 禁止

- `local-exec` / `remote-exec` は原則禁止
- DB migration・ECS deploy・外部コマンド実行を Terraform provisioner で行わない
- 例外が必要な場合は PR に理由を明記し、conftest policy 変更もセットでレビューする

## state 操作

- `terraform.tfstate` を直接編集しない
- state 移行前は必ず `terraform state pull` でバックアップを取得する
- state 移行後は各 stack で `terraform plan` を実行し、意図しない add / destroy / replace がないことを確認する

## 確認コマンド（state 分離後: `<stack>` = base / data / app）

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
