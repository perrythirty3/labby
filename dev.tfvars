aws_region         = "us-east-2"
ecr_repo_name      = "labby-app"
ecs_cluster_name   = "labby-ecs"
ecs_service_name   = "labby-ecs-service"
app_container_port = 80
desired_count      = 1
image_tag          = "latest"
# set this to your IP if you want to restrict inbound
# http_cidr          = "23.126.112.235/32"
acm_certificate_arn = "arn:aws:acm:us-east-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# http_cidr can be "0.0.0.0/0" for public, or a tighter CIDR you control
# http_cidr = "0.0.0.0/0"
