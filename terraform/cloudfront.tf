resource "aws_cloudfront_distribution" "s3_distribution" {

  aliases = var.domain_name != null ? [var.domain_name] : []

  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == null
    acm_certificate_arn            = var.domain_name != null ? aws_acm_certificate_validation.cert[0].certificate_arn : null
    ssl_support_method             = var.domain_name != null ? "sni-only" : null
    minimum_protocol_version       = var.domain_name != null ? "TLSv1.2_2021" : "TLSv1"
  }

  origin {
    domain_name = module.s3-bucket.s3_bucket_website_endpoint
    origin_id   = "S3-Website-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = module.s3_data.s3_bucket_bucket_regional_domain_name
    origin_id                = "S3-Data-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  origin {
    domain_name = replace(aws_api_gateway_stage.prod.invoke_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "API-Gateway-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    origin_path = "/prod"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.cloudfront_waf.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-Website-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    dynamic "function_association" {
      for_each = var.domain_name != null ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect[0].arn
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/users*"
    target_origin_id = "S3-Data-Origin"

    trusted_key_groups = [aws_cloudfront_key_group.app_key_group.id]

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  ordered_cache_behavior {
    path_pattern     = "/tasks*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "API-Gateway-Origin"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Accept", "Content-Type"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/upload-url*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "API-Gateway-Origin"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Accept", "Content-Type", "Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/get-access*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "API-Gateway-Origin"

    forwarded_values {
      query_string = false
      headers      = ["Authorization", "X-CloudFront-Domain"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project_name}-Distribution"
  }
}

resource "null_resource" "cloudfront_invalidation" {
  triggers = {
    frontend_hash = sha256(join("", [
      for f in fileset("${path.module}/../frontend/dist", "**") : filemd5("${path.module}/../frontend/dist/${f}")
    ]))
    config_hash = md5(aws_s3_object.config_js.content)
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution.id} --paths '/*'"
  }

  depends_on = [aws_s3_object.frontend_files, aws_s3_object.config_js]
}

resource "aws_cloudfront_public_key" "app_key" {
  name        = "user-photos-key"
  encoded_key = <<-EOF
-----BEGIN PUBLIC KEY-----
${replace(data.aws_kms_public_key.pub.public_key, "\n", "")}
-----END PUBLIC KEY-----
EOF

  lifecycle {
    ignore_changes = [encoded_key]
  }
}

resource "aws_cloudfront_key_group" "app_key_group" {
  name  = "app-key-group"
  items = [aws_cloudfront_public_key.app_key.id]

  lifecycle {
    ignore_changes = [items]
  }
}

resource "aws_cloudfront_function" "redirect" {
  count   = var.domain_name != null ? 1 : 0
  name    = "redirect-to-custom-domain"
  runtime = "cloudfront-js-1.0"
  publish = true

  code = <<-EOF
    function handler(event) {
        var request = event.request;
        var host = request.headers.host.value;
        var customDomain = '${var.domain_name}';

        if (host !== customDomain) {
            return {
                statusCode: 301,
                statusDescription: 'Moved Permanently',
                headers: {
                    "location": { "value": "https://" + customDomain + request.uri }
                }
            };
        }
        return request;
    }
  EOF
}
