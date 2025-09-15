terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "p-terraform-state-prod-681833711197"
    key     = "terraform.tfstate" # workspaces will prefix this
    region  = "us-east-2"
    encrypt = true
    # dynamodb_table = "p-terraform-locks"  # enable later when IAM is ready
  }
}

