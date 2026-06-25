resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "data_bucket_scan" {
  job_type = "SCHEDULED"
  name     = "Scan-Targeted-Data-Bucket"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [var.s3_data_bucket_id]
    }
  }

  schedule_frequency {
    daily_schedule = true
  }

  job_status = "RUNNING"
  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_classification_export_configuration" "main" {
  s3_destination {
    bucket_name = module.s3_config_logs.s3_bucket_id
    key_prefix  = "macie-results/"
    kms_key_arn = aws_kms_key.macie_key.arn
  }

  depends_on = [
    aws_s3_bucket_policy.s3_config_logs_policy,
    aws_kms_key.macie_key
  ]
}

resource "null_resource" "macie_disable_automated_discovery" {
  triggers = {
    account_id = aws_macie2_account.main.id
  }

  provisioner "local-exec" {
    command = "aws macie2 update-automated-discovery-configuration --status DISABLED --region ${data.aws_region.current.region}"
  }

  depends_on = [aws_macie2_account.main]
}
