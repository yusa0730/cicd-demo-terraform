# backend repo との連携

## 責務分離

| repo | 担当 |
|------|------|
| `cicd-demo-terraform`（このrepo） | インフラ環境の構築（ECS・RDS・ALB・SSM など） |
| `cicd-demo-backend` | アプリケーションのビルド・デプロイ・DB migration |

## DB migration の実行場所

DB migration は `cicd-demo-backend` の CD パイプラインで実行します。

```
cicd-demo-backend の deploy workflow
  ↓
ECS one-off task として npm run migrate を実行
  ↓
exit code が 0 以外なら ECS service deploy を中断
```

**Terraform apply 内で migration を実行しない理由:**

| 理由 | 説明 |
|------|------|
| 冪等性の欠如 | `local-exec` は何度実行しても同じ結果になる保証がない |
| state の汚染 | migration 失敗時に Terraform state が中途半端な状態になる |
| ライフサイクルの違い | migration はデプロイのたびに実行するが、インフラは変更があるときだけ実行する |
| ロールバック不可 | Terraform の `destroy` や `taint` は migration の影響を受けない |

## terraform-repo が提供する SSM Parameters

`environments/<env>/app/` の apply 完了後、以下の SSM Parameter が書き込まれます。
`cicd-demo-backend` の deploy workflow はこれらを読み取って動作します。

| SSM パラメータ | 内容 |
|--------------|------|
| `/ecs-demo/<env>/ecr-repository-url` | Docker イメージの push 先 ECR URL |
| `/ecs-demo/<env>/ecs-cluster-name` | デプロイ先 ECS クラスター名 |
| `/ecs-demo/<env>/ecs-service-name` | 更新対象 ECS サービス名 |
| `/ecs-demo/<env>/task-definition-family` | タスク定義のファミリー名（deploy workflow が新 revision を登録する際に参照） |
| `/ecs-demo/<env>/ecs-subnet-ids` | migration task 実行サブネット（private, カンマ区切り） |
| `/ecs-demo/<env>/ecs-security-group-id` | migration task のセキュリティグループ ID |
| `/ecs-demo/<env>/alb-dns-name` | スモークテストの接続先 ALB DNS 名 |

> **`migration-task-def-arn` について**: このパラメータは Terraform が書き出しますが、
> 現在の `cicd-demo-backend` deploy workflow では使用していません。
> deploy workflow は `task-definition-family` から最新リビジョンを取得し、
> イメージを差し替えた新リビジョンをその場で登録して migration を実行します。
> `migration-task-def-arn` は将来削除予定の legacy パラメータです。

SSM Parameter は SecureString 型（KMS CMK 暗号化）です。
`cicd-demo-backend` の deploy role には `ssm:GetParameter` と `kms:Decrypt` が必要です。

## Secrets Manager との関係

RDS の接続 URL は Secrets Manager に保存します（`/ecs-demo/<env>/database-url`）。
ECS タスクが起動時に直接参照するため、SSM には書き出しません。

```
ECS task 起動
  ↓
ECS execution role で Secrets Manager から DATABASE_URL を取得（kms:Decrypt が必要）
  ↓
コンテナ環境変数として注入
  ↓
アプリが DATABASE_URL を使って RDS に接続
```

## IAM 権限の整理

| Role | 用途 | 必要な権限 |
|------|------|-----------|
| ECS execution role | タスク起動時に secret を取得 | `secretsmanager:GetSecretValue`, `kms:Decrypt` |
| ECS task role | タスク実行中にAWS APIを使う場合 | アプリが必要とする権限 |
| app deploy role（bootstrap管理） | GitHub Actions から ECR push / ECS deploy / SSM 読み取り | `ecr:*`, `ecs:*`, `ssm:GetParameter`, `kms:Decrypt` |
