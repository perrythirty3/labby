variable "my_ip" { type = string }
variable "ecr_repo_name" { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "key_name" {
  type    = string
  default = "labby-key"
}


variable "app_container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }


variable "aws_region" {
  type    = string
  default = null # lets the AWS provider fall back to AWS_REGION env if unset
}

terraform {
  backend "s3" {
    bucket               = "p-terraform-state-prod-681833711197"
    key                  = "terraform.tfstate"
    region               = "us-east-2"
    encrypt              = true
    workspace_key_prefix = "env"
    use_lockfile         = true
  }
}
