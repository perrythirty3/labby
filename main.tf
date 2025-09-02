terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}


# deploy_ping = "noop-2025-09-01"


provider "aws" {
  region = var.region
}

# ---------------- Variables ----------------
variable "region" {
  type    = string
  default = "us-east-2"
}

# e.g. "203.0.113.42/32"
variable "my_ip" {
  type = string
}

variable "key_name" {
  type    = string
  default = "labby-key"
}

# ---------------- AMI (Amazon Linux 2023 x86_64) ----------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------- Networking ----------------
resource "aws_vpc" "labby_tf" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "labby-tf-vpc-01" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.labby_tf.id
  tags   = { Name = "labby-tf-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.labby_tf.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "${var.region}a"

  #tfsec:ignore:aws-ec2-no-public-ip-subnet - this is intentionally a public subnet for the demo
  map_public_ip_on_launch = true

  tags = { Name = "labby-tf-public-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.labby_tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "labby-tf-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# ---------------- Security Groups ----------------

# SSH from your /32
resource "aws_security_group" "ssh" {
  name        = "labby-tf-ssh"
  description = "SSH from my IP only"
  vpc_id      = aws_vpc.labby_tf.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # No outbound from the SSH SG; web SG handles egress.
  egress = []

  tags = { Name = "labby-tf-ssh" }
}


# Public HTTP (demo)
resource "aws_security_group" "web" {
  name        = "labby-tf-web"
  description = "Public HTTP"
  vpc_id      = aws_vpc.labby_tf.id

  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  # reason: demo public page; will move behind an ALB later
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-ingress-sgr - public demo page
  }

  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  # reason: allow outbound in lab; will restrict later
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr - lab allows outbound for package repos
  }

  tags = { Name = "labby-tf-web" }
}


# ---------------- EC2 ----------------
resource "aws_instance" "dev" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.ssh.id,
    aws_security_group.web.id
  ]

  key_name                    = var.key_name
  associate_public_ip_address = true

  # Require IMDSv2
  metadata_options {
    http_tokens = "required"
  }

  # Encrypt root volume (uses account default KMS)
  root_block_device {
    encrypted = true
  }

  # Start nginx and serve a page
  user_data = <<EOF
#!/bin/bash
set -euo pipefail
if command -v dnf >/dev/null 2>&1; then
  dnf -y update
  dnf -y install nginx
else
  yum -y update || true
  yum -y install nginx
fi
systemctl enable --now nginx
echo "hello from labby ✅ $(date)" > /usr/share/nginx/html/index.html
EOF
}

# chore/noop-deploy-ping


# ---------------- TERRAFORM ----------------

terraform {
  backend "s3" {
    bucket               = "p-terraform-state-prod-681833711197"
    key                  = "terraform.tfstate"
    region               = "us-east-2"
    chore/noop-deploy-ping
    encrypt              = true
    workspace_key_prefix = "env"
    use_lockfile         = true        # <- add
    # dynamodb_table     = "terraform-locks"  # <- remove
  }
}


# ========== ECS TASK EXECUTION ROLE ==========
# lets ECS pull from ECR, write logs, etc.
resource "aws_iam_role" "ecs_task_execution" {
  name = "LabbyEcsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ========== ECS TASK ROLE ==========
# your app’s containers assume this at runtime (add app-specific perms later)
resource "aws_iam_role" "ecs_task" {
  name = "LabbyEcsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# ========== LAMBDA EXECUTION ROLE ==========
resource "aws_iam_role" "lambda_exec" {
  name = "LabbyLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
=======
    dynamodb_table       = "terraform-locks"
    encrypt              = true
    workspace_key_prefix = "env"
  }

  main
}
