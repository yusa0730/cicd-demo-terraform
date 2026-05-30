# cicd-demo-terraform

このrepositoryは ECS on Fargate + RDS + ALB のアプリケーション実行基盤を管理する Terraform repository。

## Repository 責務

このrepoで管理する:
- VPC / Subnet / NAT Gateway / Internet Gateway
- ALB / ECS / ECR
- RDS (PostgreSQL)
- KMS / SSM Parameter Store / Secrets Manager
- CloudWatch Log Group

このrepoで管理しない:
- GitHub OIDC Provider
- Terraform plan/apply IAM Role
- App deploy IAM Role
- AWS account baseline (GuardDuty, CloudTrail, Config, Security Hub)

別repo:
- `cicd-demo-terraform-bootstrap` → OIDC / IAM Role
- `cicd-demo-terraform-accounts` → Account baseline
- `cicd-demo-backend` → application deploy / DB migration

## backend repo との責務分離

- DB migration は `cicd-demo-backend` の CD で ECS one-off task として実行する
- このrepoは migration に必要な ECS Task Definition / IAM / network / Secrets / SSM 出力を提供する
- Terraform apply 内で DB migration を実行しない
- `local-exec` / `remote-exec` で migration や外部コマンドを実行しない
- 詳細は [docs/backend-integration.md](docs/backend-integration.md) を参照

## State 分離方針

- stack は `base` / `data` / `app` に分ける
- apply 順序: `base` → `data` → `app`
- destroy 順序: `app` → `data` → `base`
- 原則 `1 PR = 1 stack`
- state 間の値受け渡しは `terraform_remote_state` を使う
- secret 値そのものを Terraform output に出さない
- 詳細は [docs/state-splitting.md](docs/state-splitting.md) を参照

## CI/CD 方針

- Terraform plan は PR で実行する
- Terraform apply は PR merge 後に GitHub Actions で実行する
- prod apply / destroy は GitHub Environment approval 必須
- Required check は原則 `terraform-plan / required`
- Trivy / Checkov / conftest は必須ゲートとし、理由なく skip しない
- 詳細は [docs/cicd.md](docs/cicd.md) を参照

## Claude Code 禁止事項

- `terraform apply` / `terraform destroy` を直接実行しない（CI/CD 経由のみ）
- `terraform.tfstate` を直接編集しない
- `terraform state mv` / `state pull` / `state push` は state 分離作業として明示された手順がある場合のみ使う
- AWS access key をコード・README・ログに書かない
- `environments/<env>` に GitHub OIDC Provider を追加しない
- `environments/<env>` に Terraform 実行 Role を追加しない
