resource "aws_sqs_queue" "task_deletion_dlq" {
  name                      = "cloudstack-task-deletion-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id                 = var.kms_key_app_encryption_arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue" "task_deletion_queue" {
  name                      = "cloudstack-task-deletion-queue"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  kms_master_key_id                 = var.kms_key_app_encryption_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.task_deletion_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "image_processing_queue" {
  name                      = "cloudstack-image-processing-queue"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  kms_master_key_id                 = var.kms_key_app_encryption_arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_pipes_pipe" "sqs_to_sfn_cleanup" {
  name     = "sqs-to-sfn-cleanup-pipe"
  role_arn = var.lambda_role_arns["cleanup_task"]

  source = aws_sqs_queue.task_deletion_queue.arn
  target = aws_sfn_state_machine.task_cleanup_sfn.arn

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  depends_on = [aws_sqs_queue_policy.allow_pipes_cleanup]
}

resource "aws_pipes_pipe" "sqs_to_sfn" {
  name     = "sqs-to-sfn-pipe"
  role_arn = var.lambda_role_arns["resizer"]

  source = aws_sqs_queue.image_processing_queue.arn
  target = aws_sfn_state_machine.image_processor_sfn.arn

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  depends_on = [aws_sqs_queue_policy.allow_eventbridge]
}

resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = aws_sqs_queue.image_processing_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.image_processing_queue.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.s3_upload_rule.arn }
        }
      },
      {
        Sid    = "AllowPipesAccess"
        Effect = "Allow"
        Principal = {
          Service = "pipes.amazonaws.com"
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.image_processing_queue.arn
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "allow_pipes_cleanup" {
  queue_url = aws_sqs_queue.task_deletion_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pipes.amazonaws.com"
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.task_deletion_queue.arn
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arns["cleanup_task"]
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.task_deletion_queue.arn
      }
    ]
  })
}
