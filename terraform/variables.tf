variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "CloudStack"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "is_production" {
  description = "Flag to indicate production environment for cost optimization"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD for cost alerts"
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = ["mail@example.com"]
}

variable "resizer_reserved_concurrency" {
  description = "Reserved concurrency limit for resizer Lambda (null for no limit)"
  type        = number
  default     = null
}

variable "domain_name" {
  type        = string
  description = "Primary domain name (null for CloudFront default certificate only)"
  default     = "davidlihor.com"
}
