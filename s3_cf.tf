resource "aws_s3_bucket_ownership_controls" "app_site" {
  bucket = aws_s3_bucket.app_site.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

