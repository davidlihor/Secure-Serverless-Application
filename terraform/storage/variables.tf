variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "is_production" {
  description = "Flag to indicate production environment"
  type        = bool
}

variable "bucket_data" {
  description = "Name of the S3 data bucket"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution for S3 bucket policy"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for storage encryption"
  type        = string
  default     = null
}

variable "allowed_origins" {
  description = "Allowed origins for CORS on the S3 data bucket"
  type        = list(string)
  default     = ["*"]
}
