# ecr.tf
resource "aws_ecr_repository" "app" {
  name = var.ecr_repo_name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}
