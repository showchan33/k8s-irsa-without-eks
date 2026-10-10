data "aws_instance" "node" {
  for_each = var.nodes

  filter {
    name   = "tag:Name"
    values = [each.value.ec2_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

locals {
  control_plane_nodes = {
    for key, node in data.aws_instance.node : key => node
    if var.nodes[key].role == "control_plane"
  }

  inventory_hosts = {
    for key, node in data.aws_instance.node : key => {
      ansible_host          = node.public_ip
      aws_availability_zone = node.availability_zone
      aws_instance_id       = node.id
      aws_provider_id       = "aws:///${node.availability_zone}/${node.id}"
      kubernetes_node_name = coalesce(
        try(var.nodes[key].kubernetes_node_name, null),
        split(".", node.private_dns)[0],
      )
    }
  }

  inventory = {
    all = {
      children = {
        control_plane = {
          hosts = {
            for key, host in local.inventory_hosts : key => host
            if var.nodes[key].role == "control_plane"
          }
        }
        worker = {
          hosts = {
            for key, host in local.inventory_hosts : key => host
            if var.nodes[key].role == "worker"
          }
        }
      }
    }
  }
}

resource "aws_ec2_tag" "cluster" {
  for_each = data.aws_instance.node

  resource_id = each.value.id
  key         = "kubernetes.io/cluster/${var.cluster_id}"
  value       = "owned"
}

data "aws_iam_policy_document" "ccm_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ccm" {
  statement {
    sid    = "DescribeClusterNodes"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "ccm" {
  name               = var.ccm_role_name
  assume_role_policy = data.aws_iam_policy_document.ccm_assume_role.json
}

resource "aws_iam_role_policy" "ccm" {
  name   = "cloud-controller-manager"
  role   = aws_iam_role.ccm.id
  policy = data.aws_iam_policy_document.ccm.json
}

resource "aws_iam_instance_profile" "ccm" {
  name = var.ccm_role_name
  role = aws_iam_role.ccm.name
}

resource "terraform_data" "ccm_instance_profile_association" {
  for_each = local.control_plane_nodes

  input = {
    instance_id  = each.value.id
    profile_arn  = aws_iam_instance_profile.ccm.arn
    profile_name = aws_iam_instance_profile.ccm.name
    region       = var.aws_region
  }

  triggers_replace = [
    each.value.id,
    aws_iam_instance_profile.ccm.arn,
  ]

  # The AWS provider does not expose a resource that associates an instance
  # profile with an EC2 instance already managed outside this state. Importing
  # the instance would make this root responsible for unrelated EC2 settings.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      current_profile_arn="$(aws ec2 describe-iam-instance-profile-associations \
        --filters Name=instance-id,Values=${each.value.id} \
        --query 'IamInstanceProfileAssociations[?State==`associated`].IamInstanceProfile.Arn | [0]' \
        --output text \
        --region ${var.aws_region})"

      if [ -z "$current_profile_arn" ] || [ "$current_profile_arn" = "None" ]; then
        aws ec2 associate-iam-instance-profile \
          --instance-id ${each.value.id} \
          --iam-instance-profile Name=${aws_iam_instance_profile.ccm.name} \
          --region ${var.aws_region}
      elif [ "$current_profile_arn" != "${aws_iam_instance_profile.ccm.arn}" ]; then
        echo "EC2 instance ${each.value.id} already has a different IAM Instance Profile: $current_profile_arn" >&2
        exit 1
      fi
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      association_id="$(aws ec2 describe-iam-instance-profile-associations \
        --filters Name=instance-id,Values=${self.input.instance_id} \
        --query 'IamInstanceProfileAssociations[?State==`associated` && IamInstanceProfile.Arn==`${self.input.profile_arn}`].AssociationId | [0]' \
        --output text \
        --region ${self.input.region})"

      if [ -n "$association_id" ] && [ "$association_id" != "None" ]; then
        aws ec2 disassociate-iam-instance-profile \
          --association-id "$association_id" \
          --region ${self.input.region}
      fi
    EOT
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../ansible/inventory/hosts.yaml"
  file_permission = "0644"
  content         = yamlencode(local.inventory)
}
