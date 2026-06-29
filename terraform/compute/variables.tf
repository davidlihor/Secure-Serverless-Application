variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "is_production" {
  description = "Flag to indicate production environment"
  type        = bool
}

variable "lambda_configs" {
  description = "Map of Lambda function configurations"
  type        = any
}

variable "lambda_role_arns" {
  description = "Map of Lambda function names to their IAM role ARNs"
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Security Group ID for Lambda functions"
  type        = string
}

variable "cloudfront_secret_arn" {
  description = "ARN of the CloudFront key ID secret"
  type        = string
}

variable "user_pool_arn" {
  description = "ARN of the Cognito User Pool for API Gateway authorizer"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for CORS configuration (null if not using custom domain)"
  type        = string
  default     = null
}

variable "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution for CORS"
  type        = string
}

variable "resizer_reserved_concurrency" {
  description = "Reserved concurrency limit for resizer Lambda (null for no limit)"
  type        = number
  default     = null
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Lambda environment variables"
  type        = string
}

variable "s3_data_bucket_id" {
  description = "ID of the S3 data bucket for Lambda environment variables and EventBridge"
  type        = string
}

variable "kms_key_cloudfront_signer_arn" {
  description = "ARN of the KMS key for CloudFront signing"
  type        = string
}

variable "kms_key_secrets_arn" {
  description = "ARN of the KMS key for Secrets Manager encryption (for SSM parameter encryption)"
  type        = string
}

variable "kms_key_app_encryption_arn" {
  description = "ARN of the KMS key for general application encryption"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the task deletion SQS queue"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarm notifications"
  type        = string
}

variable "api_gateway_account_arn" {
  description = "ARN of the API Gateway account (CloudWatch role)"
  type        = string
}

variable "regional_waf_acl_arn" {
  description = "ARN of the regional WAF Web ACL to associate with API Gateway"
  type        = string
}
