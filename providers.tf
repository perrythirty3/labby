terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }

  # If you use a remote backend, put it here (optional):
  # backend "s3" {
  #   bucket = "your-tf-state-bucket"
  #   key    = "envs/prod/terraform.tfstate"
  #   region = "us-east-2"
  # }
}

provider "aws" {
  region = var.aws_region
}
