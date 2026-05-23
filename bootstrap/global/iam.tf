data "aws_caller_identity" "current" {}

locals {
  environments = {
    dev  = { branch = "develop" }
    stg  = { branch = "stg" }
    prod = { branch = "prod" }
  }
}

# ── GitHub OIDC Provider ──────────────────────────────────────────────────────
# One per AWS account. Created here; never in environment stacks.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── Terraform plan roles (one per environment) ────────────────────────────────
# Used by: terraform-plan.yml (PR) and terraform-destroy.yml destroy-plan step.
# Trust: pull_request (PR plan) + ref:refs/heads/<branch> (destroy-plan via workflow_dispatch).
resource "aws_iam_role" "terraform_plan" {
  for_each = local.environments

  name = "${var.project}-${each.key}-terraform-plan-role"

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
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/${var.terraform_repo}:pull_request",
              "repo:${var.github_owner}/${var.terraform_repo}:ref:refs/heads/${each.value.branch}",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform_plan" {
  for_each = local.environments

  name = "${var.project}-${each.key}-terraform-plan-policy"
  role = aws_iam_role.terraform_plan[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "InfraRead"
        Effect = "Allow"
        Action = [
          "ec2:Describe*", "ecs:Describe*", "ecs:List*",
          "ecr:Describe*", "ecr:List*", "ecr:GetRepository*",
          "rds:Describe*", "iam:Get*", "iam:List*",
          "elasticloadbalancing:Describe*",
          "logs:Describe*", "logs:List*",
          "secretsmanager:Describe*", "secretsmanager:List*",
          "ssm:GetParameter*", "ssm:DescribeParameters",
        ]
        Resource = ["*"]
      },
    ]
  })
}

# ── Terraform apply roles (one per environment) ───────────────────────────────
# Used by: terraform-apply.yml apply step and terraform-destroy.yml destroy-apply step.
# Trust: environment:<env> (GitHub Environment gate required).
resource "aws_iam_role" "terraform_apply" {
  for_each = local.environments

  name = "${var.project}-${each.key}-terraform-apply-role"

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
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/${var.terraform_repo}:environment:${each.key}",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform_apply" {
  for_each = local.environments

  name = "${var.project}-${each.key}-terraform-apply-policy"
  role = aws_iam_role.terraform_apply[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning",
        ]
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

# ── App deploy roles (one per environment) ────────────────────────────────────
# Used by: app-repo CI to push ECR images and update ECS services.
# Trust: environment:<env> on app-repo.
resource "aws_iam_role" "app_deploy" {
  for_each = local.environments

  name = "${var.project}-${each.key}-app-deploy-role"

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
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/${var.app_repo}:environment:${each.key}",
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_deploy" {
  for_each = local.environments

  name = "${var.project}-${each.key}-app-deploy-policy"
  role = aws_iam_role.app_deploy[each.key].id

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
        Resource = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}-${each.key}"]
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
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${each.key}/*"]
      },
      {
        Sid    = "PassECSRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${each.key}-*"]
      },
    ]
  })
}
