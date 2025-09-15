output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.app_site.domain_name
}


