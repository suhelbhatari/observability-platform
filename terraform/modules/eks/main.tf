variable "name" {
  type = string
}
variable "cluster_version" {
  type    = string
  default = "1.30"
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "nodes_sg_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "node_groups" {
  description = "Map of EKS managed node groups (stateless workloads: grafana, prometheus, otel-gateway, backend, frontend)"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string # ON_DEMAND | SPOT
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.nodes_sg_id]
    endpoint_private_access = true
    endpoint_public_access  = true # restrict via public_access_cidrs in prod
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "scheduler", "controllerManager"]

  tags       = merge(var.tags, { Name = var.name })
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "this" {
  for_each        = var.node_groups
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  update_config {
    max_unavailable_percentage = 25
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

output "cluster_name"     { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_ca"       { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_issuer"      { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
