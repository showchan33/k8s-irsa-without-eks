output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "oidc_assume_role_arn" {
  description = "DEPRECATED: Use oidc_assume_role_arns."
  value       = try(aws_iam_role.oidc_assume_role["legacy"].arn, null)
}

output "oidc_assume_role_arns" {
  value = {
    for role_key, role in aws_iam_role.oidc_assume_role :
    role_key => role.arn
  }
}
