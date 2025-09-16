variable "aws_region" { type = string }
variable "ecr_repo_name" { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "app_container_port" { type = number }
variable "desired_count" { type = number }

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "http_cidr" {
  type    = string
  default = "0.0.0.0/0" # you can override with "YOUR.IP.ADDR.XX/32"
}


