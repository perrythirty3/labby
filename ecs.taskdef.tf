# CloudWatch Logs group for the ECS task
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.ecs_service_name}"
  retention_in_days = 14 # tweak as you like (1,3,5,7,14,30, etc.)
  tags = {
    Service = var.ecs_service_name
  }
}


resource "aws_ecs_task_definition" "app" {
  family                   = var.ecs_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # valid Fargate size
  memory                   = "512" # valid Fargate size
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "app",
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}",
      essential = true,

      portMappings = [
        {
          containerPort = var.app_container_port,
          hostPort      = var.app_container_port,
          protocol      = "tcp"
        }
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
  ])
}

