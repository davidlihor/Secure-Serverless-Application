resource "aws_iam_role" "lambda_roles" {
  for_each = var.lambda_configs
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
  for_each = { for k, v in var.lambda_configs : k => v if v.needs_dynamo }

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
      Resource = var.dynamodb_table_arn
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  for_each = { for k, v in var.lambda_configs : k => v if v.needs_s3_write || lookup(v, "needs_s3_read", false) || lookup(v, "needs_s3_delete", false) }

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
      Resource = ["${var.s3_data_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy" "sqs_send_access" {
  for_each = { for k, v in var.lambda_configs : k => v if lookup(v, "needs_sqs", false) }

  name = "SQSSendAccess-${each.key}"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage"
      ]
      Resource = var.sqs_queue_arns.task_deletion_queue_arn
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
          var.lambda_function_arns["resizer"],
          "${var.lambda_function_arns["resizer"]}:*"
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
          var.lambda_function_arns["cleanup_task"],
          "${var.lambda_function_arns["cleanup_task"]}:*"
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
          var.sqs_queue_arns.task_deletion_queue_arn,
          var.sqs_queue_arns.task_deletion_dlq_arn
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

resource "aws_iam_role_policy" "lambda_app_kms_access" {
  for_each = aws_iam_role.lambda_roles

  name = "AppKMSAccess-${each.key}"
  role = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.app_encryption.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_secrets_access" {
  for_each = var.lambda_configs

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
          var.cloudfront_secret_arn
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

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "CloudStack-APIGateway-CloudWatchLogs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "APIGatewayCloudWatchPolicy"
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_api_gateway_account" "api_gateway_cloudwatch" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [
    aws_iam_role_policy.api_gateway_cloudwatch
  ]
}
