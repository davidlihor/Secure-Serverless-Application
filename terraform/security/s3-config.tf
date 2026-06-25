module "s3_config_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.14.0"

  bucket           = var.bucket_config_name
  bucket_namespace = "account-regional"
  force_destroy    = !var.is_production

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
}

resource "aws_s3_bucket_policy" "s3_config_logs_policy" {
  bucket = module.s3_config_logs.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${module.s3_config_logs.s3_bucket_arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AllowConfigCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = module.s3_config_logs.s3_bucket_arn
      },
      {
        Sid       = "AllowMacieExport"
        Effect    = "Allow"
        Principal = { Service = "macie.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${module.s3_config_logs.s3_bucket_arn}/macie-results/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowMacieGetLocation"
        Effect    = "Allow"
        Principal = { Service = "macie.amazonaws.com" }
        Action    = "s3:GetBucketLocation"
        Resource  = module.s3_config_logs.s3_bucket_arn
      }
    ]
  })
}

resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name = "config-s3-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "${module.s3_config_logs.s3_bucket_arn}/*"
        Condition = {
          StringLike = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Action   = "s3:GetBucketAcl"
        Effect   = "Allow"
        Resource = module.s3_config_logs.s3_bucket_arn
      }
    ]
  })
}
