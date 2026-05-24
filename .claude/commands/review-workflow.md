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
- [ ] plan role ARN と apply role ARN が別 Secret になっているか
- [ ] `secrets:` の参照名と実際の登録名が一致しているか

### Environment / Approval
- [ ] prod apply / destroy job に `environment:` が設定されているか
- [ ] prod environment に Required reviewers が設定されているか
- [ ] dev/stg は承認なしで通る設計になっているか

### Branch Protection との整合
- [ ] Required checks 名が workflow の `jobs.<id>` または `name:` と一致しているか
- [ ] security scan job が Required checks に含まれているか

### セキュリティ
- [ ] `continue-on-error: true` でセキュリティ scan を逃していないか
- [ ] plan step の失敗が後続 step に伝播しているか（`Fail if plan failed` パターン）
- [ ] `GITHUB_TOKEN` の scope が最小権限になっているか

## 出力形式

- 問題点と影響
- 修正案（コード例付き）
- 変更すべきファイル一覧
- 破壊的変更の有無
