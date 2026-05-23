project = "ecs-demo"
env     = "prod"

aws_region = "ap-northeast-1"

vpc_cidr = "10.2.0.0/16"

availability_zones = [
  "ap-northeast-1a",
  "ap-northeast-1c",
]

public_subnet_cidrs = [
  "10.2.1.0/24",
  "10.2.2.0/24",
]

private_subnet_cidrs = [
  "10.2.11.0/24",
  "10.2.12.0/24",
]

db_name     = "app"
db_username = "app_user"

task_cpu      = "1024"
task_memory   = "2048"
desired_count = 2

app_image_uri = "public.ecr.aws/nginx/nginx:latest"

