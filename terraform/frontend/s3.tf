module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.14.0"

  bucket           = var.bucket_name
  bucket_namespace = "account-regional"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  website = {
    index_document = "index.html"
  }

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}
