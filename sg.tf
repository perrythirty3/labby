# main.tf or network.tf
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# sg.tf
resource "aws_security_group" "app" {
  name        = "${var.ecs_service_name}-sg"
  description = "Ingress to app"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.app_container_port
    to_port     = var.app_container_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # CI injects TF_VAR_my_ip
  }

  # ✅ Restrict egress to your VPC instead of 0.0.0.0/0
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }
}
