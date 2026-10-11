variable "aws_region" {
  description = "AWS region containing the Kubernetes nodes."
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_id" {
  description = "Cluster identifier used in the kubernetes.io/cluster tag."
  type        = string
}

variable "nodes" {
  description = "Kubernetes nodes discovered by their unique EC2 Name tag."
  type = map(object({
    ec2_name             = string
    role                 = string
    kubernetes_node_name = optional(string)
  }))

  validation {
    condition = alltrue([
      for node in values(var.nodes) : contains(["control_plane", "worker"], node.role)
    ])
    error_message = "nodes[*].role must be either control_plane or worker."
  }
}

variable "ccm_role_name" {
  description = "Name of the IAM role used by AWS Cloud Controller Manager through IMDS."
  type        = string
  default     = "kubernetes-aws-cloud-controller-manager"
}
