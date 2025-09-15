aws_region         = "us-east-2"
ecr_repo_name      = "labby-app"
ecs_cluster_name   = "labby-ecs"
ecs_service_name   = "labby-ecs-service"
app_container_port = 80
desired_count      = 1
image_tag          = "latest"
# set this to your IP if you want to restrict inbound
# http_cidr          = "23.126.112.235/32"
