resource "aws_iam_role" "lambda_roles" {
  for_each = local.lambda_configs
  name     = "CloudStack-Role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = [
          "lambda.amazonaws.com",
          "states.amazonaws.com",
          "pipes.amazonaws.com"
        ]
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  for_each   = aws_iam_role.lambda_roles
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  for_each   = aws_iam_role.lambda_roles
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "dynamo_access" {
  for_each = { for k, v in local.lambda_configs : k => v if v.needs_dynamo }

  name = "DynamoAccess-${each.key}"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = aws_dynamodb_table.cloudstack_table.arn
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  for_each = { for k, v in local.lambda_configs : k => v if v.needs_s3_write || lookup(v, "needs_s3_read", false) || lookup(v, "needs_s3_delete", false) }

  name = "S3Access-${each.key}"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = compact([
        lookup(each.value, "needs_s3_read", false) ? "s3:GetObject" : null,
        lookup(each.value, "needs_s3_write", false) ? "s3:PutObject" : null,
        lookup(each.value, "needs_s3_delete", false) ? "s3:DeleteObject" : null
      ])
      Resource = ["${module.s3_data.s3_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy" "sqs_send_access" {
  for_each = { for k, v in local.lambda_configs : k => v if lookup(v, "needs_sqs", false) }

  name = "SQSSendAccess-${each.key}"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage"
      ]
      Resource = aws_sqs_queue.task_deletion_queue.arn
    }]
  })
}

resource "aws_iam_role_policy" "pipe_and_sfn_access" {
  name = "PipeAndSfnAccess"
  role = aws_iam_role.lambda_roles["resizer"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "states:StartExecution"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_invoke_lambda" {
  name = "StepFunctionInvokeLambdaPolicy"
  role = aws_iam_role.lambda_roles["resizer"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.cloudstack_lambdas["resizer"].arn,
          "${aws_lambda_function.cloudstack_lambdas["resizer"].arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_cleanup_invoke_lambda" {
  name = "StepFunctionCleanupInvokeLambdaPolicy"
  role = aws_iam_role.lambda_roles["cleanup_task"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.cloudstack_lambdas["cleanup_task"].arn,
          "${aws_lambda_function.cloudstack_lambdas["cleanup_task"].arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.task_deletion_queue.arn,
          aws_sqs_queue.task_deletion_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_kms_policy" {
  name = "LambdaKMSSigningPolicy"
  role = aws_iam_role.lambda_roles["signer"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "kms:Sign"
        Effect   = "Allow"
        Resource = aws_kms_key.cloudfront_signer.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_secrets_access" {
  for_each = local.lambda_configs

  name = "SSMSecretsAccess-${each.key}"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.cloudfront_key_id.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.region}.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
