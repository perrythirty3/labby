############################################
# Application Load Balancer (public by intent)
# - HTTPS enforced (HTTP -> 301 to HTTPS)
# - drop_invalid_header_fields = true
# - Scoped tfsec ignores where public access is intentional
############################################

# Security group for the ALB (internet -> ALB :80/:443)
resource "aws_security_group" "lb" {
  name        = "labby-alb-sg"
  description = "Public ALB security group"
  vpc_id      = data.aws_vpc.default.id

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  # justification: Internet-facing ALB; port 80 used ONLY to redirect to 443
  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.http_cidr] # set to "0.0.0.0/0" if public, or restrict to your CIDR
  }

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  # justification: Internet-facing ALB; HTTPS is the required entrypoint
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.http_cidr] # set to "0.0.0.0/0" if public, or restrict to your CIDR
  }

  # tfsec:ignore:aws-ec2-no-public-egress-sgr
  # justification: Standard ALB behavior requires broad egress for health checks/DNS/etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "app" {
  name                       = "labby-alb"
  load_balancer_type         = "application"
  subnets                    = data.aws_subnets.public.ids
  security_groups            = [aws_security_group.lb.id]
  drop_invalid_header_fields = true
  # If you ever want this private instead:
  # internal = true
}

# Target group for ECS tasks (IP target type for Fargate)
resource "aws_lb_target_group" "app" {
  name        = "labby-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

# HTTPS listener (real traffic)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP listener (redirect only)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}
