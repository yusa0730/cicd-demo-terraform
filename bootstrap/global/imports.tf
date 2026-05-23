# Existing S3 state buckets — import into global state.
# Remove this file after the first successful apply.
import {
  to = aws_s3_bucket.terraform_state["dev"]
  id = "cicd-demo-terraform-dev"
}

import {
  to = aws_s3_bucket.terraform_state["stg"]
  id = "cicd-demo-terraform-stg"
}

import {
  to = aws_s3_bucket.terraform_state["prod"]
  id = "cicd-demo-terraform-prod"
}
