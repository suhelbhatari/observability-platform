output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "clickhouse_node_topology" {
  value = module.clickhouse_cluster.node_topology
}

output "clickhouse_fqdns" {
  value = module.clickhouse_cluster.fqdns
}

output "keeper_fqdns" {
  value = module.keeper_cluster.fqdns
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
