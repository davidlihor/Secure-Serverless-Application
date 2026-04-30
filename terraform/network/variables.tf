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

variable "domain_name" {
  description = "Primary domain name for Route53 (null if not using custom domain)"
  type        = string
  default     = null
}
