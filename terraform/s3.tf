resource "aws_s3_bucket" "report" {
  bucket        = var.report_bucket_name != "" ? var.report_bucket_name : null
  bucket_prefix = var.report_bucket_name == "" ? "${var.name_prefix}-" : null
}

resource "aws_s3_bucket_public_access_block" "report" {
  bucket = aws_s3_bucket.report.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "report" {
  bucket = aws_s3_bucket.report.id

  rule {
    id     = "DeleteOldReports"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "report" {
  bucket = aws_s3_bucket.report.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "report" {
  bucket = aws_s3_bucket.report.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOnlyAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.report.arn,
          "${aws_s3_bucket.report.arn}/*",
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.report]
}