resource "aws_security_group" "app" {
  name        = "${var.ecs_service_name}-sg"
  description = "Ingress to app"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.app_container_port
    to_port     = var.app_container_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # <-- uses TF_VAR_my_ip from CI, or set in tfvars locally
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
