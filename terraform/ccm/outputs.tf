output "nodes" {
  description = "Resolved EC2 and Kubernetes node information."
  value = {
    for key, node in data.aws_instance.node : key => {
      availability_zone    = node.availability_zone
      instance_id          = node.id
      instance_type        = node.instance_type
      kubernetes_node_name = local.inventory_hosts[key].kubernetes_node_name
      private_ip           = node.private_ip
      public_ip            = node.public_ip
      role                 = var.nodes[key].role
    }
  }
}

output "ccm_instance_profile_name" {
  value = aws_iam_instance_profile.ccm.name
}
