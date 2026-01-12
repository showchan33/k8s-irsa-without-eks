locals {
  values_local_output_path = "${path.module}/../../helm-chart/values.generated.yaml"
}

resource "local_file" "helm_chart_values_local" {
  filename        = local.values_local_output_path
  file_permission = "0664"
  content = templatefile("${path.module}/templates/values-generated.yaml.tmpl", {
    email                 = var.route53domains_domain.admin_contact.email
    region                = var.var_provider.region
    hosted_zone_id        = data.aws_route53_zone.this.zone_id
    access_key_id         = aws_iam_access_key.this.id
    secret_access_key     = aws_iam_access_key.this.secret
    route53_a_record_name = var.route53_a_record_name
  })
}
