module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.13.0"

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

resource "aws_s3_object" "frontend_files" {
  for_each = {
    for f in fileset("${path.module}/../../frontend/dist", "**") : f => f
    if f != "config.js"
  }

  bucket       = module.s3-bucket.s3_bucket_id
  key          = each.value
  source       = "${path.module}/../../frontend/dist/${each.value}"
  source_hash  = filemd5("${path.module}/../../frontend/dist/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
  depends_on   = [module.s3-bucket]
}

resource "aws_s3_object" "config_js" {
  bucket       = module.s3-bucket.s3_bucket_id
  key          = "config.js"
  content_type = "application/javascript"

  content = templatefile("${path.module}/../../frontend/dist/config.js", {
    user_pool_id      = var.cognito_user_pool_id
    client_id         = var.cognito_user_pool_client_id
    api_url           = ""
    cloudfront_domain = var.domain_name != null ? var.domain_name : aws_cloudfront_distribution.s3_distribution.domain_name
    region            = var.region
  })

  etag = md5(templatefile("${path.module}/../../frontend/dist/config.js", {
    user_pool_id      = var.cognito_user_pool_id
    client_id         = var.cognito_user_pool_client_id
    region            = var.region
    api_url           = ""
    cloudfront_domain = var.domain_name != null ? var.domain_name : aws_cloudfront_distribution.s3_distribution.domain_name
  }))

  depends_on = [
    module.s3-bucket,
    aws_cloudfront_distribution.s3_distribution
  ]
}
