output "eks_cluster_name"         { value = module.eks.cluster_name }
output "clickhouse_node_topology" { value = module.clickhouse_cluster.node_topology }
output "clickhouse_fqdns"         { value = module.clickhouse_cluster.fqdns }
output "alb_dns_name"             { value = module.alb.alb_dns_name }
