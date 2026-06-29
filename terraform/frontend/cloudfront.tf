resource "aws_cloudfront_distribution" "s3_distribution" {

  aliases = var.domain_name != null ? [var.domain_name] : []

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : "TLSv1"
  }

  origin {
    domain_name              = module.s3-bucket.s3_bucket_bucket_regional_domain_name
    origin_id                = "S3-Website-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  origin {
    domain_name              = var.s3_data_bucket_regional_domain_name
    origin_id                = "S3-Data-Origin"
    origin_access_control_id = var.cloudfront_origin_access_control_id
  }

  origin {
    domain_name = replace(var.api_gateway_stage_invoke_url, "/^https?://([^/]*).*/", "$1")
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
  web_acl_id          = var.waf_acl_arn

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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
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
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "API-Gateway-Origin"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Accept", "Content-Type", "Origin", "X-CloudFront-Domain", "x-cloudfront-domain"]

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project_name}-Distribution"
  }
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

resource "aws_cloudfront_function" "spa_routing" {
  name    = "${var.project_name}-spa-routing"
  runtime = "cloudfront-js-1.0"
  publish = true

  code = <<-EOF
    function handler(event) {
        var request = event.request;
        var host = request.headers.host ? request.headers.host.value : "";
        var customDomain = '${var.domain_name != null ? var.domain_name : ""}';
        var uri = request.uri;

        if (customDomain && host && host !== customDomain) {
            return {
                statusCode: 301,
                statusDescription: 'Moved Permanently',
                headers: {
                    "location": { "value": "https://" + customDomain + uri }
                }
            };
        }

        if (uri.indexOf('.') === -1 && uri.indexOf('/api/') !== 0 && uri.indexOf('/users/') !== 0) {
            request.uri = '/index.html';
        }

        return request;
    }
  EOF
}

data "aws_route53_zone" "main" {
  count        = var.domain_name != null ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "root_domain" {
  count   = var.domain_name != null ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-frontend-oac"
  description                       = "Origin Access Control for Frontend S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
