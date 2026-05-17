data "aws_caller_identity" "current" {}

# GitHub OIDC provider — create once per AWS account.
# stg/prod environments reference this via data source.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── Terraform role ────────────────────────────────────────────────────────────
resource "aws_iam_role" "terraform" {
  name = "${local.name_prefix}-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:pull_request",
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/develop",
              "repo:${var.github_org}/${var.github_repo}:environment:${var.env}",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform" {
  name = "${local.name_prefix}-terraform-policy"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "TerraformStateLock"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = ["*"]
      },
      {
        Sid    = "InfraManage"
        Effect = "Allow"
        Action = [
          "ec2:*", "ecs:*", "ecr:*", "rds:*", "iam:*",
          "elasticloadbalancing:*", "logs:*", "secretsmanager:*", "ssm:*",
        ]
        Resource = ["*"]
      },
    ]
  })
}

# ── App deploy role ───────────────────────────────────────────────────────────
# Scoped to deploy operations only. No IAM or Terraform permissions.
resource "aws_iam_role" "app_deploy" {
  name = "${local.name_prefix}-app-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.app_github_repo}:ref:refs/heads/develop",
              "repo:${var.github_org}/${var.app_github_repo}:environment:${var.env}",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_deploy" {
  name = "${local.name_prefix}-app-deploy-policy"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart", "ecr:InitiateLayerUpload", "ecr:PutImage",
        ]
        Resource = [module.ecr.repository_arn]
      },
      {
        Sid    = "ECSDeployAndMigrate"
        Effect = "Allow"
        Action = [
          "ecs:RunTask", "ecs:DescribeTasks",
          "ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition",
          "ecs:UpdateService", "ecs:DescribeServices",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "SSMRead"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
      },
      {
        Sid      = "PassECSRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [
          module.ecs_app.ecs_execution_role_arn,
          module.ecs_app.ecs_task_role_arn,
        ]
      },
    ]
  })
}
