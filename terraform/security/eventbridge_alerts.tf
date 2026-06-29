resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-security-alerts"
  kms_master_key_id = aws_kms_key.app_encryption.arn

  tags = {
    Name = "${var.project_name}-security-alerts"
  }
}

resource "aws_sns_topic_policy" "security_alerts_policy" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "security_findings" {
  name        = "${var.project_name}-security-findings"
  description = "Aggregates GuardDuty, Macie, Inspector, and Access Analyzer findings"

  event_pattern = jsonencode({
    source = [
      "aws.guardduty",
      "aws.macie",
      "aws.inspector2",
      "aws.access-analyzer"
    ]
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.security_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}
