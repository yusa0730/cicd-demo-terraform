# /fix-trivy

Trivy の config scan 失敗を解消する。

## 手順

1. `/tmp/trivy-output.txt` または Step Summary の Trivy セクションを読む
2. 各 FAIL を一覧化する（リソース名 / check ID / 説明）
3. 各 FAIL を分類する:
   - **修正する**: Terraformコードで対応可能なもの
   - **`.trivyignore.yaml` でskip**: スコープ外・設計上許容するもの
4. 修正する場合はコードを直す
5. skip する場合は `.trivyignore.yaml` に理由付きで追記する:
   ```yaml
   - id: AVD-AWS-0123
     paths:
       - environments/dev
     reason: "Demo environment: HTTPS/ACM is out of scope"
   ```
6. 修正後に以下で確認する:
   ```
   trivy config \
     --tf-vars environments/<env>/terraform.tfvars \
     --format table \
     --exit-code 1 \
     environments/<env>
   ```
7. 結果を報告する

## 注意

- Trivy と Checkov は別ツールで異なる check ID を使う（混同しない）
- `trivy config` は `--tf-vars` を渡すことで変数依存の誤検知を減らせる
- skip は `.trivyignore.yaml` に理由付きで書く（サイレント skip 禁止）
