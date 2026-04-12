resource "aws_acm_certificate" "cert" {
  count             = var.domain_name != null ? 1 : 0
  provider          = aws.virginia
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.domain_name != null ? 1 : 0
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
