# Terraform State 分離

## レイヤー構成

`environments/<env>` は 3 層の独立した Terraform state に分割します。
ライフサイクルが異なるリソースを分けることで、変更の影響範囲を限定します。

| レイヤー | ディレクトリ | 管理リソース |
|---------|-------------|-------------|
| `base` | `environments/<env>/base/` | KMS / VPC / Subnet / NAT Gateway |
| `data` | `environments/<env>/data/` | RDS / DB Subnet Group / Secrets Manager |
| `app` | `environments/<env>/app/` | ECR / ALB / ECS / SSM Parameters / SG rules |

## S3 バックエンドキー命名規則

```
ecs-demo/<env>/<stack>/terraform.tfstate
```

例:
```
ecs-demo/dev/base/terraform.tfstate
ecs-demo/dev/data/terraform.tfstate
ecs-demo/dev/app/terraform.tfstate
```

## Apply / Destroy 順序

Apply（作る順序）:
```
base → data → app
```

base がなければ data は作れない（VPC ID が必要）。
data がなければ app は作れない（RDS SG の ID が必要）。

Destroy（消す順序）:
```
app → data → base
```

依存している側から先に消す。逆順で実行するとリソース削除が失敗する。

## クロス State 参照

`terraform_remote_state` を使ってレイヤー間の値を参照します。

```
base の outputs
  ├── kms_key_arn
  ├── vpc_id
  ├── public_subnet_ids
  └── private_subnet_ids
        ↓ data が参照
data の outputs
  ├── database_url_secret_arn
  └── rds_security_group_id
        ↓ app が参照
app は base + data の両方を参照
```

`data/main.tf` での記述例:

```hcl
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "cicd-demo-terraform-dev"
    key    = "ecs-demo/dev/base/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "database" {
  vpc_id      = data.terraform_remote_state.base.outputs.vpc_id
  kms_key_arn = data.terraform_remote_state.base.outputs.kms_key_arn
}
```

## secret 値を output に出さない理由

Terraform state ファイルはすべての output を平文で保存します。
state への読み取り権限がある人は output の内容を全員読めます。

- パスワード・接続文字列・証明書などの secret 値は output に出さない
- secret の受け渡しが必要な場合は Secrets Manager の ARN のみを output し、値そのものは渡さない

## S3 Backend 設定

- `use_lockfile = true`：S3 ネイティブロックで同時 apply を防ぐ
- バケットの versioning を有効化：state 破壊時の復旧に必須

```hcl
terraform {
  backend "s3" {
    bucket       = "cicd-demo-terraform-dev"
    key          = "ecs-demo/dev/base/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
```

## Legacy State との関係

`environments/dev/` 直下の単一 state（`ecs-demo/dev/terraform.tfstate`）は移行完了後に廃止します。
移行は以下の 3 PR に分けて行います。

| PR | 内容 |
|----|------|
| PR 1 | base / data / app ディレクトリ追加（ファイル追加のみ、既存 state 変更なし） |
| PR 2 | `terraform state mv` による state 移行 + workflow 更新（dev） |
| PR 3 | stg / prod への展開 |

## State 移行手順（PR 2 で実施）

```bash
# 1. 現在の state をバックアップ
terraform -chdir=environments/dev state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. 新しい state バックエンドを初期化
terraform -chdir=environments/dev/base init
terraform -chdir=environments/dev/data init
terraform -chdir=environments/dev/app init

# 3. base に移行（KMS + Network）
terraform -chdir=environments/dev state mv \
  -state-out=environments/dev/base/moved.tfstate \
  module.kms module.kms
terraform -chdir=environments/dev state mv \
  -state-out=environments/dev/base/moved.tfstate \
  module.network module.network

# 4. 移行後に plan を確認（差分がゼロであることを確認）
terraform -chdir=environments/dev/base plan -var-file=terraform.tfvars
# Expected: No changes. Your infrastructure matches the configuration.

# data / app も同様に繰り返す
```

> state 移行後は必ず `terraform plan` を実行して **No changes** であることを確認してからマージする。
> 意図しない `add` / `destroy` / `replace` が出た場合は移行手順を見直す。
