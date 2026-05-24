# /fix-checkov

Checkovの失敗を「修正対象」と「理由付きskip対象」に分類して解消する。

## 手順

1. 直近のCheckovログまたは現在の出力を読む
2. Failed checks を一覧化する
3. 各 check を以下に分類する:
   - **修正する**: Terraformコードで安全に直せるもの
   - **理由付きskip**: デモ/コスト/スコープ外の正当な理由があるもの
   - **prodでは禁止**: devでのみ許容し、prodには適用すべきでないもの
4. 修正対象はTerraformコードを直す
5. skip対象は `.checkov.yml` に理由付きコメントで追記する（inline `#checkov:skip` でも可）
6. 修正後に以下を実行して確認する:
   ```
   terraform fmt -recursive
   checkov -d environments/<env> --framework terraform --config-file .checkov.yml --quiet
   ```
7. 変更ファイル、解消件数、残課題を報告する

## 禁止

- 理由なし skip
- `continue-on-error: true` で握りつぶす
- prod にも影響する危険な skip を無言で追加する
- skip 件数を増やすだけで根本を直さない

## 分類基準（参考）

| パターン | 方針 |
|---|---|
| 暗号化未設定（KMS/AES256） | 修正 |
| SG rule に description なし | 修正 |
| egress protocol="-1" | 修正（絞り込み）|
| HTTPS リスナー未設定 | ACM/ドメインが範囲外ならskip（理由明記）|
| WAF 未設定 | 別スタックで管理ならskip（理由明記）|
| Multi-AZ 無効 | dev/stgコスト最適化ならskip（理由明記）|
| 削除保護無効 | destroyデモのためdevではskip（理由明記）|
