output "lint_hold_ecr_repo_name" {
  value     = var.ecr_repo_name
  sensitive = true
}

output "lint_hold_ecs_cluster_name" {
  value     = var.ecs_cluster_name
  sensitive = true
}

output "lint_hold_ecs_service_name" {
  value     = var.ecs_service_name
  sensitive = true
}

output "lint_hold_app_container_port" {
  value     = var.app_container_port
  sensitive = true
}

output "lint_hold_desired_count" {
  value     = var.desired_count
  sensitive = true
}

output "lint_hold_vpc_id" {
  value     = var.vpc_id
  sensitive = true
}

output "lint_hold_public_subnet_ids" {
  value     = var.public_subnet_ids
  sensitive = true
}
