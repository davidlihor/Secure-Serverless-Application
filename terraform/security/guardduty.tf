resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "lambda" {
  detector_id = aws_guardduty_detector.main.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "malware" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "DISABLED"
  }

  additional_configuration {
    name   = "EC2_AGENT_MANAGEMENT"
    status = "DISABLED"
  }

  additional_configuration {
    name   = "ECS_FARGATE_AGENT_MANAGEMENT"
    status = "DISABLED"
  }
}

resource "aws_guardduty_malware_protection_plan" "s3_data_scan" {
  role = aws_iam_role.guardduty_malware_scan_role.arn

  protected_resource {
    s3_bucket {
      bucket_name = var.s3_data_bucket_id
    }
  }

  actions {
    tagging {
      status = "ENABLED"
    }
  }

  depends_on = [
    aws_iam_role_policy.guardduty_malware_full_access
  ]
}

resource "aws_iam_role" "guardduty_malware_scan_role" {
  name = "GuardDutyMalwareScanRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "malware-protection-plan.guardduty.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "guardduty_malware_full_access" {
  name = "GuardDutyMalwareS3FullAccess"
  role = aws_iam_role.guardduty_malware_scan_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManagedRuleActions"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:DeleteRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:DescribeRule",
          "events:ListRules",
          "events:ListTargetsByRule",
          "events:TagResource",
          "events:UntagResource"
        ]
        Resource = [
          "arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*"
        ]
      },
      {
        Sid    = "AllowPostScanTag"
        Effect = "Allow"
        Action = [
          "s3:PutObjectTagging",
          "s3:GetObjectTagging",
          "s3:PutObjectVersionTagging",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${var.s3_data_bucket_arn}/*"]
      },
      {
        Sid    = "AllowEnableS3EventBridgeEventsAndValidation"
        Effect = "Allow"
        Action = [
          "s3:PutBucketNotification",
          "s3:GetBucketNotification",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [var.s3_data_bucket_arn]
      },
      {
        Sid      = "AllowPutValidationObject"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.s3_data_bucket_arn}/malware-protection-resource-validation-object"]
      },
      {
        Sid      = "AllowScanObject"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = ["${var.s3_data_bucket_arn}/*"]
      }
    ]
  })
}
