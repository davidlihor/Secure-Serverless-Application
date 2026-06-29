provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "random" {

}

module "network" {
  source = "./network"
  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  project_name  = var.project_name
  environment   = var.environment
  region        = var.region
  is_production = var.is_production
  domain_name   = var.domain_name
}

module "security" {
  source = "./security"

  project_name        = var.project_name
  environment         = var.environment
  region              = var.region
  is_production       = var.is_production
  lambda_configs      = local.lambda_configs
  budget_limit        = var.monthly_budget_limit
  budget_alert_emails = var.budget_alert_emails
  bucket_config_name  = local.bucket_config
  dynamodb_table_arn  = module.storage.dynamodb_table_arn
  s3_data_bucket_arn  = module.storage.s3_data_bucket_arn
  s3_data_bucket_id   = module.storage.s3_data_bucket_id

  sqs_queue_arns = {
    task_deletion_queue_arn    = module.compute.sqs_task_deletion_queue_arn
    task_deletion_dlq_arn      = module.compute.sqs_task_deletion_dlq_arn
    image_processing_queue_arn = module.compute.sqs_image_processing_queue_arn
  }

  lambda_function_arns     = module.compute.lambda_function_arns
  cloudfront_public_key_id = module.frontend.cloudfront_public_key_id
  cloudfront_secret_arn    = module.security.cloudfront_secret_arn
  kms_key_secrets_arn      = module.security.kms_key_secrets_arn
}

module "storage" {
  source = "./storage"

  project_name                = var.project_name
  environment                 = var.environment
  is_production               = var.is_production
  bucket_data                 = local.bucket_data
  cloudfront_distribution_arn = module.frontend.cloudfront_distribution_arn
  kms_key_arn                 = module.security.kms_key_app_encryption_arn
  allowed_origins             = var.domain_name != null ? ["https://${var.domain_name}"] : ["https://${module.frontend.cloudfront_distribution_domain_name}"]
}

module "compute" {
  source = "./compute"

  project_name                  = var.project_name
  environment                   = var.environment
  region                        = var.region
  is_production                 = var.is_production
  lambda_configs                = local.lambda_configs
  lambda_role_arns              = module.security.lambda_role_arns
  private_subnet_ids            = module.network.private_subnet_ids
  lambda_sg_id                  = module.network.lambda_security_group_id
  cloudfront_secret_arn         = module.security.cloudfront_secret_arn
  user_pool_arn                 = module.security.cognito_user_pool_arn
  domain_name                   = var.domain_name
  cloudfront_domain_name        = var.domain_name != null ? var.domain_name : module.frontend.cloudfront_distribution_domain_name
  resizer_reserved_concurrency  = var.resizer_reserved_concurrency
  dynamodb_table_name           = module.storage.dynamodb_table_name
  s3_data_bucket_id             = module.storage.s3_data_bucket_id
  kms_key_cloudfront_signer_arn = module.security.kms_key_cloudfront_signer_arn
  kms_key_secrets_arn           = module.security.kms_key_secrets_arn
  kms_key_app_encryption_arn    = module.security.kms_key_app_encryption_arn
  sqs_queue_url                 = module.compute.sqs_task_deletion_queue_url
  sns_topic_arn                 = module.security.config_sns_topic_arn
  api_gateway_account_arn       = module.security.api_gateway_account_arn
  regional_waf_acl_arn          = module.security.regional_waf_acl_arn
}

module "frontend" {
  source = "./frontend"
  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
  project_name                        = var.project_name
  environment                         = var.environment
  region                              = var.region
  domain_name                         = var.domain_name
  bucket_name                         = local.bucket_name
  cognito_user_pool_id                = module.security.cognito_user_pool_id
  cognito_user_pool_client_id         = module.security.cognito_user_pool_client_id
  s3_data_bucket_id                   = module.storage.s3_data_bucket_id
  s3_data_bucket_regional_domain_name = module.storage.s3_data_bucket_regional_domain_name
  cloudfront_origin_access_control_id = module.storage.cloudfront_origin_access_control_id
  api_gateway_stage_invoke_url        = module.compute.api_gateway_stage_invoke_url
  waf_acl_arn                         = module.security.waf_acl_arn
  kms_key_cloudfront_signer_id        = module.security.kms_key_cloudfront_signer_id
  acm_certificate_arn                 = module.network.acm_certificate_arn
}
