resource "aws_route53_record" "app_a" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.route53_a_record_name
  type    = "A"
  ttl     = 300
  records = [var.route53_a_record_ip]
}
