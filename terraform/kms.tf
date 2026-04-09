resource "aws_kms_key" "cloudfront_signer" {
  description              = "KMS Key for CloudFront Signing"
  customer_master_key_spec = "RSA_2048"
  key_usage                = "SIGN_VERIFY"
}

data "aws_kms_public_key" "pub" {
  key_id = aws_kms_key.cloudfront_signer.id
}

resource "aws_kms_key" "backup_key" {
  count                   = var.is_production ? 1 : 0
  description             = "KMS Key for encrypting DynamoDB backups"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "backup_key_alias" {
  count         = var.is_production ? 1 : 0
  name          = "alias/${var.project_name}-backup-key"
  target_key_id = aws_kms_key.backup_key[0].key_id
}
