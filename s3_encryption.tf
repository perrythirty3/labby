resource "aws_s3_bucket_server_side_encryption_configuration" "app_site" {
  bucket = aws_s3_bucket.app_site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_app.arn
    }
    bucket_key_enabled = true
  }
}
