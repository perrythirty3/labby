# ECS service to run the task
resource "aws_ecs_service" "app" {
  name             = "labby-app-svc"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true # turn ON for quick testing without an ALB
  }

  # optional: don’t churn on task def revisions unless you intend to
  lifecycle {
    ignore_changes = [task_definition]
  }
}
