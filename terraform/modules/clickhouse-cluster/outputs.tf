output "instance_ids" {
  value = { for k, v in aws_instance.clickhouse : k => v.id }
}

output "private_ips" {
  value = { for k, v in aws_instance.clickhouse : k => v.private_ip }
}

output "node_topology" {
  description = "shard/replica map, consumed by Ansible to render remote_servers.xml"
  value       = local.node_map
}

output "fqdns" {
  value = { for k, v in aws_route53_record.clickhouse_node : k => v.fqdn }
}
