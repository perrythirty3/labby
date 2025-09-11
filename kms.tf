resource "aws_kms_key" "s3_app" {
  description             = "CMK for app_site bucket encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "s3_app" {
  name          = "alias/labby-s3-app"
  target_key_id = aws_kms_key.s3_app.id
}
