terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# -------- Variables --------
variable "region" {
  type    = string
  default = "us-east-2"
}

variable "my_ip" {
  type = string
}

variable "key_name" {
  type    = string
  default = "labby-key"
}

# -------- AMI (Amazon Linux 2023 x86_64) --------
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

# -------- Networking --------
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
  vpc_id                  = aws_vpc.labby_tf.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "labby-tf-public-a" }
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

# -------- Security Group (SSH from your /32) --------
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "labby-tf-ssh" }
}



# -------- Outputs --------
output "public_ip" {
  value = aws_instance.dev.public_ip
}

output "ssh_command" {
  value = "ssh -i <PATH-TO-PEM> ec2-user@${aws_instance.dev.public_ip}"
}


/*
# --- DISABLED IAM role for SSM (lets you use Session Manager) ---
resource "aws_iam_role" "ssm_role" {
  name = "labby-tf-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "labby-tf-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

*/

# --- SG for web traffic (public HTTP only) ---
resource "aws_security_group" "web" {
  name        = "labby-tf-web"
  description = "Public HTTP"
  vpc_id      = aws_vpc.labby_tf.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "labby-tf-web" }
}


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

  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name#

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    # Update OS
    dnf -y update || yum -y update || true

    # Install nginx (Amazon Linux 2023 uses dnf)
    if command -v dnf >/dev/null 2>&1; then
      dnf -y install nginx
      systemctl enable nginx
      systemctl start nginx
    else
      yum -y install nginx
      systemctl enable nginx
      systemctl start nginx
    fi

    # Simple landing page
    echo "Hello from Labby! $(hostname) $(date)" > /usr/share/nginx/html/index.html
  EOF

  tags = { Name = "labby-tf-ec2" }
}
