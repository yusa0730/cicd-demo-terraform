---
paths:
  - ".github/workflows/*.yml"
  - ".github/workflows/*.yaml"
---

# GitHub Actions Rules

- OIDC `sub` 条件と workflow trigger の整合を確認する
- Repository Secrets と Environment Secrets を混同しない
- Required check は原則 `terraform-plan / required` のみを指定する
- reusable workflow 内部の job 名を Branch Protection の Required check に直接指定しない
- security scan に `continue-on-error: true` を使わない
- apply / destroy は GitHub Environment approval を通す
- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` を workflow の `env:` に含める
- workflow 変更後は、対象 check が直近 7 日以内に成功していて GitHub UI 上で選択できることを確認する
