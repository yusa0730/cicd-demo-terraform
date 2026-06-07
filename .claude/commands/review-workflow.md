# /review-workflow

GitHub Actions workflow の OIDC・Secrets・Environment・Branch Protection の整合性をレビューする。

## 確認事項

### OIDC / 認証

- [ ] `pull_request` trigger に対して plan role のみ使われているか
- [ ] `push` / `merge` trigger に対して apply role が使われているか
- [ ] OIDC `sub` 条件と IAM trust policy が一致しているか
- [ ] `pull_request_target` を使っていないか（fork PRからのsecret漏洩リスク）

### Secrets / 変数

- [ ] Repository Secrets と Environment Secrets の使い分けが正しいか
- [ ] plan role ARN は Repository Secret（`AWS_TERRAFORM_PLAN_ROLE_ARN_<ENV>`）を使っているか
- [ ] apply role ARN は Environment Secret（`AWS_TERRAFORM_ROLE_ARN`）を使っているか
- [ ] `secrets:` の参照名と実際の登録名が一致しているか

### Environment / Approval

- [ ] apply / destroy job に `environment:` が設定されているか
- [ ] dev / stg / prod すべての GitHub Environment に Required reviewers が設定されているか（docs/cicd.md を参照）
- [ ] prod の承認要件が他の環境より厳しく設定されているか

### Branch Protection との整合

- [ ] Required check に `terraform-plan / required` が設定されているか
- [ ] reusable workflow 内部の job 名を直接 Required check にしていないか
- [ ] workflow 変更後は対象 check が直近 7 日以内に成功して GitHub UI で選択できることを確認したか

### セキュリティ

- [ ] `continue-on-error: true` でセキュリティ scan を逃していないか
- [ ] plan step の失敗が後続 step に伝播しているか（`Fail if plan failed` パターン）
- [ ] `GITHUB_TOKEN` の scope が最小権限になっているか

## 出力形式

- 問題点と影響
- 修正案（コード例付き）
- 変更すべきファイル一覧
- 破壊的変更の有無
