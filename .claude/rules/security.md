---
paths:
  - ".checkov.yml"
  - "policy/**/*.rego"
  - "**/*.tf"
  - "**/*.tfvars"
---

# Security Rules

- Trivy / Checkov / conftest は必須ゲート（`continue-on-error: true` で握りつぶさない）
- CI を通すためだけの skip は禁止
- skip する場合は理由をコメントまたは `.checkov.yml` に残す
- dev 限定の例外か prod にも適用される例外かを明記する
- `local-exec` / `remote-exec` を許可する policy 緩和は禁止。必要な場合は明示レビューする
- `pull_request_target` は使用しない（fork PR からの secret 漏洩を防ぐため）
- Secrets Manager の値を Terraform output に出力しない
- `terraform_remote_state` の output に出してよいのは ID / ARN / name などの参照情報のみ
- DB password・database URL・SecretString・access token は output 禁止
