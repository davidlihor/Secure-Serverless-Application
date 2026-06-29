module "s3_data" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.14.0"

  bucket           = var.bucket_data
  bucket_namespace = "account-regional"
  force_destroy    = !var.is_production

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = { enabled = true }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = var.kms_key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule = [{
    id      = "intelligent-tiering"
    enabled = true

    transition = [{
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }]
  }]
}

resource "aws_s3_bucket_cors_configuration" "data" {
  bucket = module.s3_data.s3_bucket_id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = var.allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-data-oac"
  description                       = "Secure access control for S3 data"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = module.s3_data.s3_bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging"
        ],
        Resource = "${module.s3_data.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn"                                   = var.cloudfront_distribution_arn,
            "s3:ExistingObjectTag/GuardDutyMalwareScanStatus" = "NO_THREATS_FOUND"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "s3_eventbridge_notify" {
  bucket      = module.s3_data.s3_bucket_id
  eventbridge = true
}
