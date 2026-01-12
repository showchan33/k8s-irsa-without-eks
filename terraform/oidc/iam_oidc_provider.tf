locals {
  effective_oidc_assume_roles = (
    length(var.oidc_assume_roles) > 0
    ? var.oidc_assume_roles
    : {
      legacy = var.oidc_assume_role
    }
  )

  oidc_issuer_host = trim(
    replace(replace(var.oidc_provider.url, "https://", ""), "http://", ""),
    "/"
  )

  role_policy_attachments = {
    for rp in flatten([
      for role_key, role in local.effective_oidc_assume_roles : [
        for policy_arn in try(role.managed_policy_arns, []) : {
          key        = "${role_key}:${policy_arn}"
          role_key   = role_key
          policy_arn = policy_arn
        }
      ]
    ]) : rp.key => rp
  }
}

data "tls_certificate" "oidc" {
  url = var.oidc_provider.url
}

resource "aws_iam_openid_connect_provider" "this" {
  url            = var.oidc_provider.url
  client_id_list = var.oidc_provider.client_id_list

  thumbprint_list = [
    data.tls_certificate.oidc.certificates[0].sha1_fingerprint
  ]
}

data "aws_iam_policy_document" "oidc_assume_role" {
  for_each = local.effective_oidc_assume_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = [try(each.value.audience, "sts.amazonaws.com")]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
  }
}

resource "aws_iam_role" "oidc_assume_role" {
  for_each = local.effective_oidc_assume_roles

  name = each.value.service_account
  # IAM role path must start/end with "/" and only contain alphanumerics or "/".
  path = (
    length(replace(each.value.namespace, "/[^0-9A-Za-z]/", "")) > 0
    ? "/${replace(each.value.namespace, "/[^0-9A-Za-z]/", "")}/"
    : "/"
  )
  tags               = try(each.value.tags, null)
  assume_role_policy = data.aws_iam_policy_document.oidc_assume_role[each.key].json
}

resource "aws_iam_role_policy_attachment" "oidc_assume_role" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.oidc_assume_role[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "oidc_assume_role_inline" {
  for_each = {
    for role_key, role in local.effective_oidc_assume_roles :
    role_key => role
    if try(role.inline_policy_json, null) != null
  }

  name   = "inline"
  role   = aws_iam_role.oidc_assume_role[each.key].id
  policy = each.value.inline_policy_json
}
