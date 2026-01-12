resource "aws_iam_user" "this" {
  name = var.iam_user.name
  path = try(var.iam_user.path, null)
  tags = try(var.iam_user.tags, null)
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

locals {
  route53_access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ChangeRecordsInThisZone"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.zone_id}"
      },
      {
        Sid      = "AllowGetChange"
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "*"
      },
      {
        Sid      = "AllowListZones"
        Effect   = "Allow"
        Action   = "route53:ListHostedZones"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "this" {
  name        = var.iam_policy.name
  description = try(var.iam_policy.description, null)
  path        = try(var.iam_policy.path, null)
  policy      = local.route53_access_policy
  tags        = try(var.iam_policy.tags, null)
}

resource "aws_iam_user_policy_attachment" "this" {
  user       = aws_iam_user.this.name
  policy_arn = aws_iam_policy.this.arn
}
