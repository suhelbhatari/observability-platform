# Builds a shard x replica matrix of EC2 instances, e.g. shard_count=3, replica_count=2 -> 6 nodes.
# Each instance is tagged with ch_shard / ch_replica so Ansible's dynamic inventory can
# group them correctly and render the ClickHouse cluster XML (remote_servers config).

locals {
  az_count = length(var.database_subnet_ids)

  # flatten shard x replica into a single list of node definitions
  nodes = flatten([
    for s in range(var.shard_count) : [
      for r in range(var.replica_count) : {
        shard   = s + 1
        replica = r + 1
        # distribute nodes round-robin across AZs for HA
        subnet_id = var.database_subnet_ids[(s * var.replica_count + r) % local.az_count]
      }
    ]
  ])

  node_map = { for idx, n in local.nodes : "s${n.shard}-r${n.replica}" => n }
}

resource "aws_instance" "clickhouse" {
  for_each = local.node_map

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name              = "${var.name}-ch-shard${each.value.shard}-replica${each.value.replica}"
    Role              = "clickhouse"
    ch_shard          = tostring(each.value.shard)
    ch_replica        = tostring(each.value.replica)
    ansible_group     = "clickhouse_nodes"
    MonitoringManaged = "true"
  })

  lifecycle {
    ignore_changes = [ami] # Ansible/golden-AMI pipeline manages in-place updates; avoid Terraform replacing nodes on AMI bumps
  }
}

# Dedicated high-IOPS data volume, attached separately so it can be resized/snapshotted
# independent of the root volume and instance lifecycle.
resource "aws_ebs_volume" "clickhouse_data" {
  for_each          = local.node_map
  availability_zone = aws_instance.clickhouse[each.key].availability_zone
  size              = var.data_volume_size_gb
  type              = "io2"
  iops              = var.data_volume_iops
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.name}-ch-data-${each.key}"
  })
}

resource "aws_volume_attachment" "clickhouse_data" {
  for_each    = local.node_map
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.clickhouse_data[each.key].id
  instance_id = aws_instance.clickhouse[each.key].id
}

# Internal Route53 zone entries so ClickHouse cluster config + Ansible can address nodes by stable DNS
resource "aws_route53_record" "clickhouse_node" {
  for_each = local.node_map
  zone_id  = var.internal_zone_id
  name     = "ch-${each.key}.${var.name}.internal"
  type     = "A"
  ttl      = 60
  records  = [aws_instance.clickhouse[each.key].private_ip]
}

variable "internal_zone_id" {
  description = "Route53 private hosted zone ID for internal service discovery"
  type        = string
}
