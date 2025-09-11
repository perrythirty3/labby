variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
}

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}


output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}



resource "aws_ecr_repository" "app" {
  name = var.ecr_repo_name
}
