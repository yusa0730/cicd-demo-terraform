# If the GitHub OIDC Provider already exists in this AWS account, import it here.
# Remove this file after the first successful apply.
import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::218317313594:oidc-provider/token.actions.githubusercontent.com"
}
