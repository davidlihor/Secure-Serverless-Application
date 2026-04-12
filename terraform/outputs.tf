output "app_url" {
  description = "The principal URL for accessing the application"
  value       = var.domain_name != null ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "s3_website_url" {
  description = "S3 bucket website endpoint URL"
  value       = module.s3-bucket.s3_bucket_website_endpoint
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.pool.id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.client.id
  sensitive   = false
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.cloudstack_table.name
}


output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.s3_distribution.id
  description = "CloudFront Distribution ID"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "CloudFront Domain Name"
}

output "waf_web_acl_id" {
  value       = aws_wafv2_web_acl.cloudfront_waf.id
  description = "WAF Web ACL ID"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnets
}

output "lambda_security_group_id" {
  description = "Security Group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = module.vpc.nat_public_ips
}