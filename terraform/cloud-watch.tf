resource "aws_cloudwatch_dashboard" "compliance" {
  dashboard_name = "${var.project_name}-Compliance-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown   = "# AWS Config Compliance Dashboard - ${var.project_name}"
          background = "transparent"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 4
        properties = {
          title  = "Compliance Score"
          region = var.region
          metrics = [
            ["AWS/Config", "ComplianceScore", { stat = "Average", period = 300 }]
          ]
          annotations = {
            horizontal = [
              {
                value = 90
                label = "Target 90%"
                color = "#2ca02c"
              },
              {
                value = 70
                label = "Warning 70%"
                color = "#ff7f0e"
              }
            ]
          }
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 4
        properties = {
          title  = "Non-Compliant Resources"
          region = var.region
          metrics = [
            ["AWS/Config", "NumberOfNonCompliantResources", { stat = "Sum", period = 300, color = "#d62728" }]
          ]
          annotations = {
            horizontal = [
              {
                value = 0
                label = "Goal: 0"
                color = "#2ca02c"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 4
        properties = {
          title  = "Resources Evaluated"
          region = var.region
          metrics = [
            ["AWS/Config", "NumberOfResourcesEvaluated", { stat = "Sum", period = 300 }]
          ]
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 5
        width  = 24
        height = 1
        properties = {
          markdown   = "## Auto-Remediation Status"
          background = "transparent"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 5
        properties = {
          title  = "Remediation Success vs Failure"
          region = var.region
          metrics = [
            ["AWS/Config", "NumberOfRemediationSuccess", { stat = "Sum", period = 300, color = "#2ca02c", label = "Success" }],
            [".", "NumberOfRemediationFailure", { stat = "Sum", period = 300, color = "#d62728", label = "Failure" }]
          ]
          legend = {
            position = "bottom"
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 5
        properties = {
          title  = "Remediation Success Rate (%)"
          region = var.region
          metrics = [
            [{ expression = "(m1 / (m1 + m2)) * 100", label = "Success Rate", id = "e1" }],
            ["AWS/Config", "NumberOfRemediationSuccess", { id = "m1", visible = false, stat = "Sum", period = 300 }],
            [".", "NumberOfRemediationFailure", { id = "m2", visible = false, stat = "Sum", period = 300 }]
          ]
          annotations = {
            horizontal = [
              {
                value = 95
                label = "Target 95%"
                color = "#2ca02c"
              }
            ]
          }
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 11
        width  = 24
        height = 1
        properties = {
          markdown   = "## Config Rules Status"
          background = "transparent"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 4
        properties = {
          title  = "EBS Encryption Rule"
          region = var.region
          metrics = [
            ["AWS/Config", "NumberOfNonCompliantResources", "ConfigRuleName", "ebs-volumes-encrypted", { stat = "Sum", period = 300, color = "#d62728", label = "Non-Compliant" }],
            [".", ".", ".", ".", { stat = "Sum", period = 300, color = "#2ca02c", visible = false, label = "Compliant" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 4
        properties = {
          title  = "SSH Restriction Rule"
          region = var.region
          metrics = [
            ["AWS/Config", "NumberOfNonCompliantResources", "ConfigRuleName", "restricted-common-ports", { stat = "Sum", period = 300, color = "#d62728", label = "Non-Compliant" }]
          ]
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 16
        width  = 24
        height = 1
        properties = {
          markdown   = "---\n*Last updated: ${timestamp()}* | **${var.project_name}** | Environment: ${var.environment}"
          background = "transparent"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "low_compliance" {
  alarm_name          = "${var.project_name}-LowComplianceScore"
  alarm_description   = "Alert when compliance score drops below 80%"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ComplianceScore"
  namespace           = "AWS/Config"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.config_updates.arn]

  tags = {
    Name = "${var.project_name}-LowComplianceAlarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "remediation_failures" {
  alarm_name          = "${var.project_name}-RemediationFailures"
  alarm_description   = "Alert when remediation failures occur"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfRemediationFailure"
  namespace           = "AWS/Config"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.config_updates.arn]

  tags = {
    Name = "${var.project_name}-RemediationFailureAlarm"
  }
}
