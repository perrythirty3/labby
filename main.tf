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
  availability_zone = "${var.aws_region}a"

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

# ========== ECS TASK EXECUTION ROLE ==========
# lets ECS pull from ECR, write logs, etc.
resource "aws_iam_role" "ecs_task_execution" {
  name = "LabbyEcsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
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
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# ========== LAMBDA EXECUTION ROLE ==========
resource "aws_iam_role" "lambda_exec" {
  name = "LabbyLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Simple public S3 website for a quick test ---

resource "random_id" "app" {
  byte_length = 3
}

resource "aws_s3_bucket" "app_site" {
  bucket        = "labby-app-site-${random_id.app.hex}"
  force_destroy = true
  tags          = { Name = "labby-app-site" }
}

resource "aws_s3_bucket_ownership_controls" "app_site" {
  bucket = aws_s3_bucket.app_site.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "app_site" {
  bucket                  = aws_s3_bucket.app_site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "app_site" {
  bucket = aws_s3_bucket.app_site.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

data "aws_iam_policy_document" "app_site_public" {
  statement {
    sid       = "PublicReadGetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app_site.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "app_site_public" {
  bucket = aws_s3_bucket.app_site.id
  policy = data.aws_iam_policy_document.app_site_public.json
}

# tiny index so you see something
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.app_site.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<HTML
<!doctype html>
<html><head><meta charset="utf-8"><title>Labby</title></head>
<body style="font-family:system-ui;margin:2rem">
  <h1>✅ Hello from Labby</h1>
  <p>${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}</p>
</body></html>
HTML
}

# (optional) outputs
output "app_site_bucket" { value = aws_s3_bucket.app_site.bucket }
output "app_site_website_url" {
  value = aws_s3_bucket_website_configuration.app_site.website_endpoint
}


