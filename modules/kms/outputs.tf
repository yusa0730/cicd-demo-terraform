output "key_arn" {
  value = aws_kms_key.app.arn
}

output "key_id" {
  value = aws_kms_key.app.key_id
}
