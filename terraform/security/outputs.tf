# KMS Keys
output "kms_key_cloudfront_signer_arn" {
  description = "ARN of the KMS key for CloudFront signing"
  value       = aws_kms_key.cloudfront_signer.arn
}

output "kms_key_cloudfront_signer_id" {
  description = "ID of the KMS key for CloudFront signing"
  value       = aws_kms_key.cloudfront_signer.id
}

output "kms_key_secrets_arn" {
  description = "ARN of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_secrets_id" {
  description = "ID of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets.id
}

output "kms_key_backup_arn" {
  description = "ARN of the KMS key for backups (production only)"
  value       = var.is_production ? aws_kms_key.backup_key[0].arn : null
}

# IAM Roles
output "lambda_role_arns" {
  description = "Map of Lambda function names to their IAM role ARNs"
  value       = { for k, v in aws_iam_role.lambda_roles : k => v.arn }
}

output "lambda_role_names" {
  description = "Map of Lambda function names to their IAM role names"
  value       = { for k, v in aws_iam_role.lambda_roles : k => v.name }
}

output "api_gateway_cloudwatch_role_arn" {
  description = "ARN of the IAM role for API Gateway CloudWatch logs"
  value       = aws_iam_role.api_gateway_cloudwatch.arn
}

output "api_gateway_account_arn" {
  description = "ARN of the API Gateway account (CloudWatch role)"
  value       = aws_api_gateway_account.api_gateway_cloudwatch.cloudwatch_role_arn
}

output "config_role_arn" {
  description = "ARN of the IAM role for AWS Config"
  value       = aws_iam_role.config_role.arn
}

# Cognito
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.pool.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.pool.arn
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.client.id
}

# Secrets Manager
output "cloudfront_secret_arn" {
  description = "ARN of the CloudFront key ID secret"
  value       = aws_secretsmanager_secret.cloudfront_key_id.arn
}

# SNS Topic
output "config_sns_topic_arn" {
  description = "ARN of the SNS topic for AWS Config and CloudWatch alarms"
  value       = aws_sns_topic.config_updates.arn
}

# WAF
output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL for CloudFront"
  value       = aws_wafv2_web_acl.cloudfront_waf.arn
}

output "waf_acl_id" {
  description = "ID of the WAF Web ACL for CloudFront"
  value       = aws_wafv2_web_acl.cloudfront_waf.id
}

output "kms_key_app_encryption_arn" {
  description = "ARN of the KMS key for general application encryption"
  value       = aws_kms_key.app_encryption.arn
}

output "regional_waf_acl_arn" {
  description = "ARN of the regional WAF Web ACL for API Gateway"
  value       = aws_wafv2_web_acl.regional_waf.arn
}
