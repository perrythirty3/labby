# --- network.tf (reuse default VPC & public subnets) ---

# Use the account's default VPC in this region
data "aws_vpc" "default" {
  default = true
}

# Grab public subnets in that default VPC (those with mapPublicIpOnLaunch = true)
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Security group for the Fargate service
resource "aws_security_group" "app" {
  name        = "labby-app-svc-sg"
  description = "Ingress to app"
  vpc_id      = data.aws_vpc.default.id

  # Let the ALB reach the tasks on the app port
  ingress {
    description     = "From ALB only"
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Make subnets available to the rest of the module
locals {
  public_subnet_ids = data.aws_subnets.public.ids
}

