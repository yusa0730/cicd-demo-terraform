project = "ecs-demo"
env     = "dev"

aws_region = "ap-northeast-1"

task_cpu      = "512"
task_memory   = "1024"
desired_count = 1

app_image_uri = "public.ecr.aws/nginx/nginx:latest"
