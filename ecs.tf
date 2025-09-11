resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
}

resource "aws_ecs_service" "app" {
  name          = var.ecs_service_name
  cluster       = aws_ecs_cluster.this.id
  desired_count = var.desired_count

  network_configuration {
    subnets         = var.public_subnet_ids
    security_groups = [aws_security_group.app.id]
  }
}
