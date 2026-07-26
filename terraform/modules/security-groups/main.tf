variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

# ---------- ALB: public ingress ----------
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = var.vpc_id
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
  lifecycle { create_before_destroy = true }
}

# ---------- EKS worker nodes ----------
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.name}-eks-nodes-"
  vpc_id      = var.vpc_id
  ingress {
    description     = "From ALB"
    from_port       = 1024
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-eks-nodes-sg" })
  lifecycle { create_before_destroy = true }
}

# ---------- ClickHouse cluster (EC2) ----------
resource "aws_security_group" "clickhouse" {
  name_prefix = "${var.name}-clickhouse-"
  vpc_id      = var.vpc_id

  ingress { # HTTP interface (used by OTel collector exporter, Grafana datasource)
    description     = "ClickHouse HTTP"
    from_port       = 8123
    to_port         = 8123
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }
  ingress { # Native TCP protocol
    description     = "ClickHouse native"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }
  ingress { # Inter-node replication + distributed queries
    description = "Inter-shard/replica"
    from_port   = 9000
    to_port     = 9009
    protocol    = "tcp"
    self        = true
  }
  ingress { # Keeper (coordination, formerly ZooKeeper)
    description = "ClickHouse Keeper"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    self        = true
  }
  ingress { # Keeper raft
    description = "Keeper raft"
    from_port   = 9234
    to_port     = 9234
    protocol    = "tcp"
    self        = true
  }
  ingress {
    description = "SSH from bastion/VPN CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress { # node_exporter scrape
    description     = "node_exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-clickhouse-sg" })
  lifecycle { create_before_destroy = true }
}

output "alb_sg_id"        { value = aws_security_group.alb.id }
output "eks_nodes_sg_id"  { value = aws_security_group.eks_nodes.id }
output "clickhouse_sg_id" { value = aws_security_group.clickhouse.id }
