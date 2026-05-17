project = "ecs-demo"
env     = "dev"

aws_region = "ap-northeast-1"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "ap-northeast-1a",
  "ap-northeast-1c",
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24",
]

db_name     = "app"
db_username = "app_user"

task_cpu      = "512"
task_memory   = "1024"
desired_count = 1

app_image_uri = "public.ecr.aws/nginx/nginx:latest"

github_org      = "your-org"
github_repo     = "terraform-repo"
app_github_repo = "app-repo"
