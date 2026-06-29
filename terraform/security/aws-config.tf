resource "aws_config_configuration_recorder" "main" {
  name     = "main-recorder"
  role_arn = aws_iam_role.config_role.arn
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}


resource "aws_config_config_rule" "ebs_optimized_check" {
  name = "ebs-volumes-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_remediation_configuration" "ebs_remediation" {
  config_rule_name = aws_config_config_rule.ebs_optimized_check.name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWSConfigRemediation-EnableEbsEncryptionByDefault"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation_role.arn
  }

  depends_on = [aws_config_config_rule.ebs_optimized_check]
}

resource "aws_config_config_rule" "ssh_restricted" {
  name = "restricted-common-ports"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_remediation_configuration" "ssh_remediation" {
  config_rule_name = aws_config_config_rule.ssh_restricted.name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DisablePublicAccessForSecurityGroup"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation_role.arn
  }

  parameter {
    name           = "GroupId"
    resource_value = "RESOURCE_ID"
  }

  depends_on = [
    aws_config_config_rule.ebs_optimized_check,
    aws_config_config_rule.ssh_restricted
  ]
}


resource "aws_iam_role" "remediation_role" {
  name = "ConfigRemediationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_automation_attach" {
  role       = aws_iam_role.remediation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy_attachment" "ebs_remediation_attach" {
  role       = aws_iam_role.remediation_role.name
  policy_arn = aws_iam_policy.ebs_remediation_policy.arn
}

resource "aws_iam_role_policy_attachment" "sg_remediation_attach" {
  role       = aws_iam_role.remediation_role.name
  policy_arn = aws_iam_policy.sg_remediation_policy.arn
}


resource "aws_iam_policy" "ebs_remediation_policy" {
  name        = "EBSRemediationPolicy"
  description = "Allow enabling EBS implicit encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:ModifyEbsDefaultKmsKeyId",
          "ec2:EnableEbsEncryptionByDefault",
          "ec2:GetEbsEncryptionByDefault"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "sg_remediation_policy" {
  name        = "SGRemediationPolicy"
  description = "Allows automated closure of open SSH ports"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "config_updates" {
  name              = "config-compliance-updates"
  kms_master_key_id = aws_kms_key.app_encryption.arn
}

resource "aws_config_delivery_channel" "main" {
  name           = "main-channel"
  s3_bucket_name = module.s3_config_logs.s3_bucket_id
  sns_topic_arn  = aws_sns_topic.config_updates.arn

  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.s3_config_logs_policy,
    aws_iam_role_policy_attachment.config_policy_attach,
    aws_iam_role_policy.config_s3_policy
  ]
}
