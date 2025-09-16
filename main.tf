



# ---------------- Security Groups ----------------

# SSH from your /32


# Public HTTP (demo)
resource "aws_security_group" "web" {
  name        = "labby-tf-web"
  description = "Public HTTP"
  vpc_id      = data.aws_vpc.default.id

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


resource "aws_s3_bucket_public_access_block" "app_site" {
  bucket                  = aws_s3_bucket.app_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "app_site" {
  bucket = aws_s3_bucket.app_site.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
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


resource "aws_cloudfront_distribution" "app_site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    # IMPORTANT: use the bucket's regional domain (not website endpoint)
    domain_name              = aws_s3_bucket.app_site.bucket_regional_domain_name
    origin_id                = "s3-app-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.app_site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-app-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# requires aws provider >= 4.9 (v5.x recommended)
resource "aws_cloudfront_origin_access_control" "app_site" {
  name                              = "${aws_s3_bucket.app_site.bucket}-oac"
  description                       = "OAC for app_site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "app_site_allow_cf" {
  bucket = aws_s3_bucket.app_site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontReadOAC",
      Effect    = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action    = ["s3:GetObject"],
      Resource  = "${aws_s3_bucket.app_site.arn}/*",
      Condition = {
        StringEquals = {
          "AWS:SourceArn" : "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.app_site.id}"
        }
      }
    }]
  })
}









