# /before-pr

PR を出す前の最終チェックリストを実行する。

## 実行手順

以下を順番に確認・実行する:

### 1. フォーマット

```bash
terraform fmt -recursive
```

差分があれば git add してコミットする。

### 2. 静的解析（`<stack>` = base / data / app）

```bash
checkov -d environments/<env>/<stack> --framework terraform --config-file .checkov.yml --quiet
trivy config --tf-vars environments/<env>/<stack>/terraform.tfvars --format table environments/<env>/<stack>
```

失敗があれば `/fix-checkov` または `/fix-trivy` を実行する。

### 3. コード確認

- [ ] `terraform apply` / `terraform destroy` のコマンドをコードに残していないか
- [ ] AWS access key / secret が含まれていないか
- [ ] `.checkov.yml` の新規 skip に理由が書かれているか
- [ ] `continue-on-error: true` を新たに追加していないか
- [ ] `terraform_remote_state` の output に secret 値（パスワード・接続文字列）を出していないか

### 4. 変更スコープ確認

- [ ] 変更が `environments/<env>/<stack>` または `modules/` に限定されているか
- [ ] bootstrap 側（OIDC Provider / IAM Role）に影響していないか
- [ ] 1 PR = 1 stack の原則を守っているか
- [ ] 意図しないモジュール変更がないか（`git diff --stat` で確認）

### 5. コミット確認

```bash
git status
git diff --staged
```

コミットされていない変更がないか確認する。

### 6. PR description 確認

以下を PR description に含める:
- 変更の目的
- 影響するリソースと stack
- skip した Checkov / Trivy check とその理由
- テスト方法（plan 結果の確認方法）
