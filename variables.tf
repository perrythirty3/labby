variable "aws_region" { type = string }
variable "ecr_repo_name" { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }

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
