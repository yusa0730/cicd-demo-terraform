output "instance_id" {
  description = "Bastion EC2 インスタンス ID（SSM Session Manager 接続に使用）"
  value       = aws_instance.bastion.id
}

output "security_group_id" {
  description = "Bastion セキュリティグループ ID"
  value       = aws_security_group.bastion.id
}
