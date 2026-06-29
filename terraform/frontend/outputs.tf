output "s3_bucket_id" {
  description = "ID of the S3 bucket hosting the frontend"
  value       = module.s3-bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket hosting the frontend"
  value       = module.s3-bucket.s3_bucket_arn
}

output "s3_bucket_website_endpoint" {
  description = "Regional domain name of the S3 bucket"
  value       = module.s3-bucket.s3_bucket_bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.arn
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_public_key_id" {
  description = "ID of the CloudFront public key"
  value       = aws_cloudfront_public_key.app_key.id
}

output "cloudfront_key_group_id" {
  description = "ID of the CloudFront key group"
  value       = aws_cloudfront_key_group.app_key_group.id
}
