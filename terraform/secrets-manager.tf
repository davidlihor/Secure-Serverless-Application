resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "cloudfront_key_id" {
  name                    = "${var.project_name}/${var.environment}/cloudfront/key-id"
  description             = "CloudFront Public Key ID for URL signing"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  tags = {
    Name        = "CloudFront Key ID"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "cloudfront_key_id" {
  secret_id     = aws_secretsmanager_secret.cloudfront_key_id.id
  secret_string = jsonencode({
    key_id = aws_cloudfront_public_key.app_key.id
  })
}
