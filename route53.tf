# Route53 Hosted Zone
resource "aws_route53_zone" "primary" {
  name = "cloud-breadcrumbs.com"
}

# AWS Certificate Manager (ACM) Certificate
# Note: This will be created in the region specified by your default provider (ap-northeast-1).
resource "aws_acm_certificate" "cert" {
  domain_name       = "cloud-breadcrumbs.com"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records in Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
  records         = [each.value.record]
  ttl             = 60
}

# Certificate validation waits for DNS records to be propagated
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 A record to point the domain to the ALB
resource "aws_route53_record" "alb_record" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "cloud-breadcrumbs.com"
  type    = "A"
  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}