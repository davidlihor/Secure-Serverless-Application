data "archive_file" "lambda_zip" {
  for_each    = local.lambda_configs
  type        = "zip"
  source_dir  = "${path.module}/../lambda-functions"
  output_path = "${path.module}/files/${each.key}.zip"

  excludes = setsubtract(
    fileset("${path.module}/../lambda-functions", "*.py"),
    ["${each.key}.py", "config_helper.py"]
  )
}

resource "aws_lambda_function" "cloudstack_lambdas" {
  for_each = local.lambda_configs

  function_name = "CloudStack-${each.key}"
  role          = aws_iam_role.lambda_roles[each.key].arn
  handler       = "${each.key}.lambda_handler"
  runtime       = "python3.12"
  architectures   = ["x86_64"]

  memory_size = each.value.memory
  timeout     = each.value.timeout

  reserved_concurrent_executions = each.key == "resizer" && var.is_production ? var.resizer_reserved_concurrency : null
  
  layers = compact([
    local.secrets_extension_arn,
    each.key == "resizer" ? "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-Pillow:10" : null
  ])

  filename         = data.archive_file.lambda_zip[each.key].output_path
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = merge({
      PARAMETERS_SECRETS_EXTENSION_CACHE_ENABLED = "true"
      PARAMETERS_SECRETS_EXTENSION_CACHE_SIZE  = "100"
      SSM_PARAMETER_STORE_TTL                  = "300"
      SECRETS_MANAGER_TTL                        = "300"
      PARAMETERS_SECRETS_EXTENSION_LOG_LEVEL     = "INFO"

      SSM_PARAMETER_PREFIX = "/${var.project_name}/${var.environment}"
      SECRET_ARN_CLOUDFRONT = aws_secretsmanager_secret.cloudfront_key_id.arn
    }, each.key == "delete_task" ? {
      DELETE_QUEUE_URL_PARAM = "/${var.project_name}/${var.environment}/sqs/delete-queue-url"
    } : {})
  }

  depends_on = [module.vpc, aws_iam_role_policy_attachment.lambda_vpc]
}

resource "aws_lambda_permission" "apigw_lambda" {
  for_each = { for k, v in aws_lambda_function.cloudstack_lambdas : k => v if k != "resizer" }

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
