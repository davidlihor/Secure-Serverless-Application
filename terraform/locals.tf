locals {
  secrets_extension_arn = "arn:aws:lambda:${var.region}:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension:12"

  lambda_configs = {
    "create_task"    = { timeout = 3, memory = 128, needs_s3_write = false, needs_dynamo = true }
    "get_tasks"      = { timeout = 3, memory = 128, needs_s3_write = false, needs_dynamo = true }
    "update_task"    = { timeout = 3, memory = 128, needs_s3_write = false, needs_dynamo = true }
    "delete_task"    = { timeout = 3, memory = 128, needs_s3_write = false, needs_dynamo = true, needs_sqs = true }
    "get_upload_url" = { timeout = 3, memory = 128, needs_s3_write = true, needs_dynamo = true }
    "resizer"        = { timeout = 30, memory = 1024, needs_s3_read = true, needs_s3_write = true, needs_dynamo = true }
    "signer"         = { timeout = 3, memory = 128, needs_s3_write = false, needs_dynamo = false }
    "cleanup_task"   = { timeout = 30, memory = 256, needs_s3_delete = true, needs_dynamo = true }
  }

  bucket_name   = "cloudstack-project-${random_string.suffix.result}"
  bucket_data   = "cloudstack-data-${random_string.suffix.result}"
  bucket_config = "cloudstack-config-${random_string.suffix.result}"

  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
  }

  api_methods = {
    "POST_tasks"    = { res = aws_api_gateway_resource.tasks.id, method = "POST", lambda = "create_task" }
    "GET_tasks"     = { res = aws_api_gateway_resource.tasks.id, method = "GET", lambda = "get_tasks" }
    "PUT_taskId"    = { res = aws_api_gateway_resource.task_id.id, method = "PUT", lambda = "update_task" }
    "DELETE_taskId" = { res = aws_api_gateway_resource.task_id.id, method = "DELETE", lambda = "delete_task" }
    "POST_upload"   = { res = aws_api_gateway_resource.upload_url.id, method = "POST", lambda = "get_upload_url" }
    "GET_access"    = { res = aws_api_gateway_resource.get_access.id, method = "GET", lambda = "signer" }
  }

  cors_resources = {
    "tasks"      = aws_api_gateway_resource.tasks.id
    "taskId"     = aws_api_gateway_resource.task_id.id
    "upload_url" = aws_api_gateway_resource.upload_url.id
  }
}


