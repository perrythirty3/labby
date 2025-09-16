resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.ecs_service_name}"
  retention_in_days = 7
}

locals {
  app_container_definition = [
    {
      name      = "app",
      image     = local.app_image,
      essential = true,
      portMappings = [
        { containerPort = var.app_container_port, protocol = "tcp" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ]
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.ecs_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode(local.app_container_definition)
}

locals {
  app_image = var.ecr_repo_name != "" ? "${var.ecr_repo_name}:${var.image_tag}" : "public.ecr.aws/docker/library/nginx:stable"
}
