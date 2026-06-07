data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "bastion" {
  name = "${var.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secrets_read" {
  name = "${var.name_prefix}-bastion-secrets-read"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowGetDbSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_url_secret_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Bastion host - SSM Session Manager only, no inbound SSH"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-bastion-sg" }
}

resource "aws_instance" "bastion" {
  #checkov:skip=CKV_AWS_126: EC2 detailed monitoring is out of scope for this CI/CD demo.
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  associate_public_ip_address = false
  monitoring                  = false

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y postgresql15
  EOF
  )

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "${var.name_prefix}-bastion" }
}
