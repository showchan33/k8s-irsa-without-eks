output "route53_access_key_id" {
  value = aws_iam_access_key.this.id
}

output "route53_access_key_secret" {
  value     = aws_iam_access_key.this.secret
  sensitive = true
}

output "route53domains_domain_name" {
  value = var.route53domains_domain.domain_name
}

output "route53domains_registrant_email" {
  value = var.route53domains_domain.registrant_contact.email
}

output "route53_admin_email" {
  value = var.route53domains_domain.admin_contact.email
}

output "route53_region" {
  value = var.var_provider.region
}

output "route53_hosted_zone_id" {
  value = data.aws_route53_zone.this.zone_id
}
