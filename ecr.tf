# ecr.tf
resource "aws_ecr_repository" "app" {
  name = var.ecr_repo_name

  # ✅ scan on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # ✅ immutable tags so “latest” can’t be overwritten
  image_tag_mutability = "IMMUTABLE"
}
