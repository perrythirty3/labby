# Cluster
resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
}

# Logs for the task
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.ecs_service_name}"
  retention_in_days = 14
}

# Task execution & task roles are assumed to exist in iam.tf.
# If you don't have them yet, tell me and I'll paste them again.

# Task Definition (Fargate)
resource "aws_ecs_task_definition" "app" {
  family                   = var.ecs_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
   
  ])
}

# Service (this is where network_configuration belongs)
