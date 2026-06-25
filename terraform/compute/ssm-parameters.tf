resource "aws_ssm_parameter" "table_name" {
  # checkov:skip=CKV2_AWS_34:DynamoDB table name is structural metadata and does not contain sensitive data
  name  = "/${var.project_name}/${var.environment}/dynamodb/table-name"
  type  = "String"
  value = var.dynamodb_table_name
  tier  = "Standard"

  tags = {
    Name = "DynamoDB Table Name"
  }
}

resource "aws_ssm_parameter" "bucket_name" {
  # checkov:skip=CKV2_AWS_34:S3 bucket name is non-sensitive configuration data
  name  = "/${var.project_name}/${var.environment}/s3/data-bucket"
  type  = "String"
  value = var.s3_data_bucket_id
  tier  = "Standard"

  tags = {
    Name = "S3 Data Bucket"
  }
}

resource "aws_ssm_parameter" "kms_key_id" {
  name   = "/${var.project_name}/${var.environment}/kms/cloudfront-signer-arn"
  type   = "SecureString"
  value  = var.kms_key_cloudfront_signer_arn
  key_id = var.kms_key_secrets_arn
  tier   = "Standard"

  tags = {
    Name = "KMS CloudFront Signer ARN"
  }
}

resource "aws_ssm_parameter" "delete_queue_url" {
  # checkov:skip=CKV2_AWS_34:SQS queue URL is environment infrastructure data, not a secret
  name  = "/${var.project_name}/${var.environment}/sqs/delete-queue-url"
  type  = "String"
  value = aws_sqs_queue.task_deletion_queue.id
  tier  = "Standard"

  tags = {
    Name = "SQS Delete Queue URL"
  }
}

resource "aws_ssm_parameter" "config_prefix" {
  # checkov:skip=CKV2_AWS_34:Configuration prefix path is plain text and does not require encryption
  name  = "/${var.project_name}/${var.environment}/config/prefix"
  type  = "String"
  value = "/${var.project_name}/${var.environment}"
  tier  = "Standard"
}
