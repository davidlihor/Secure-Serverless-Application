output "app_url" {
  description = "The principal URL for accessing the application"
  value       = var.domain_name != null ? "https://${var.domain_name}" : "https://${module.frontend.cloudfront_distribution_domain_name}"
}

output "frontend_bucket_id" {
  description = "ID of the S3 bucket hosting the frontend"
  value       = module.frontend.s3_bucket_id
}

output "s3_website_url" {
  description = "S3 bucket regional domain name"
  value       = module.frontend.s3_bucket_website_endpoint
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.compute.api_gateway_stage_invoke_url
}

output "config_api_endpoint" {
  description = "The API Endpoint to be written into the frontend config.js"
  value       = var.domain_name != null ? "https://${var.domain_name}" : module.compute.api_gateway_stage_invoke_url
}

output "config_cloudfront_domain" {
  description = "The CloudFront Domain to be written into the frontend config.js"
  value       = var.domain_name != null ? var.domain_name : module.frontend.cloudfront_distribution_domain_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.security.cognito_user_pool_id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.security.cognito_user_pool_client_id
  sensitive   = false
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.storage.dynamodb_table_name
}

output "cloudfront_distribution_id" {
  value       = module.frontend.cloudfront_distribution_id
  description = "CloudFront Distribution ID"
}

output "cloudfront_domain_name" {
  value       = module.frontend.cloudfront_distribution_domain_name
  description = "CloudFront Domain Name"
}

output "waf_web_acl_id" {
  value       = module.security.waf_acl_id
  description = "WAF Web ACL ID"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.network.vpc_cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "database_subnets" {
  description = "Database subnet IDs"
  value       = module.network.database_subnet_ids
}

output "lambda_security_group_id" {
  description = "Security Group ID for Lambda functions"
  value       = module.network.lambda_security_group_id
}

output "nat_gateway_ips" {
  description = "NAT Gateway IDs"
  value       = module.network.nat_gateway_ids
}