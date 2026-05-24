# /tf-plan-review

Terraform plan の出力を安全性の観点でレビューする。

## 手順

1. `terraform show -no-color tfplan` または Step Summary の plan セクションを読む
2. 以下の観点で変更を分類する:
   - **create**: 新規リソース。依存関係と命名を確認
   - **update in-place**: 無停止変更か確認
   - **replace (destroy + create)**: サービス影響を確認
   - **destroy**: 意図した削除か確認
3. 以下を確認する:
   - bootstrap 側リソース（OIDC Provider / IAM Role）が含まれていないか
   - RDS / ECS など本番データに影響するリソースの replace がないか
   - KMS key の destroy がないか（暗号データが失われる）
   - SSM / Secrets Manager の意図しない変更がないか
4. 問題がなければ承認サマリを出す
5. 問題があれば修正提案を出す

## 危険フラグ

以下が plan に含まれていたら必ず警告する:

- `aws_kms_key` の destroy
- `aws_db_instance` の replace
- `aws_iam_role` の destroy（bootstrap 関連）
- `aws_iam_openid_connect_provider` の destroy
- `aws_s3_bucket` の destroy（tfstate バケット）
- destroy が 5 件以上
