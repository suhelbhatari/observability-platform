# ClickHouse Keeper: 3 or 5 node quorum for cluster coordination (DDL, replication metadata).
# Always deploy an odd number of nodes for quorum. 3 is standard for prod.

variable "name" {
  type = string
}
variable "database_subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "m6g.large" # Keeper is CPU/network light, doesn't need ClickHouse's memory profile
}
variable "ami_id" {
  type = string
}
variable "key_name" {
  type = string
}
variable "node_count" {
  type    = number
  default = 3
}
variable "instance_profile_name" {
  type = string
}
variable "internal_zone_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_instance" "keeper" {
  count                  = var.node_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.database_subnet_ids[count.index % length(var.database_subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name          = "${var.name}-keeper-${count.index + 1}"
    Role          = "clickhouse-keeper"
    keeper_id     = tostring(count.index + 1)
    ansible_group = "keeper_nodes"
  })
}

resource "aws_route53_record" "keeper_node" {
  count   = var.node_count
  zone_id = var.internal_zone_id
  name    = "keeper-${count.index + 1}.${var.name}.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.keeper[count.index].private_ip]
}

output "private_ips" {
  value = aws_instance.keeper[*].private_ip
}
output "fqdns" {
  value = aws_route53_record.keeper_node[*].fqdn
}
