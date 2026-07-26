# DR region: smaller footprint by default (2 shards vs 3), same replication factor.
# ClickHouse cross-region replication: see docs/DISASTER_RECOVERY.md for strategy
# (async S3-based backup shipping + ReplicatedMergeTree, promotion runbook included).

module "vpc" {
  source = "../../modules/vpc"

  name                  = "obs-prod-euw1"
  cidr_block            = "10.1.0.0/16"
  azs                   = var.azs
  public_subnet_cidrs   = ["10.1.0.0/22", "10.1.4.0/22", "10.1.8.0/22"]
  private_subnet_cidrs  = ["10.1.32.0/20", "10.1.48.0/20", "10.1.64.0/20"]
  database_subnet_cidrs = ["10.1.128.0/24", "10.1.129.0/24", "10.1.130.0/24"]
}

module "security_groups" {
  source   = "../../modules/security-groups"
  name     = "obs-prod-euw1"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = "10.1.0.0/16"
}

module "eks" {
  source             = "../../modules/eks"
  name               = "obs-prod-euw1"
  cluster_version    = "1.30"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  nodes_sg_id        = module.security_groups.eks_nodes_sg_id

  node_groups = {
    "observability-core" = {
      instance_types = ["m6i.xlarge"]
      min_size       = 2
      max_size       = 6
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      labels         = { workload = "observability-core" }
      taints         = []
    }
  }
}

module "keeper_cluster" {
  source                 = "../../modules/keeper-cluster"
  name                   = "obs-prod-euw1"
  database_subnet_ids    = module.vpc.database_subnet_ids
  security_group_id      = module.security_groups.clickhouse_sg_id
  ami_id                 = var.ami_id
  key_name               = var.key_name
  node_count             = 3
  instance_profile_name  = var.instance_profile_name
  internal_zone_id       = var.internal_zone_id
}

module "clickhouse_cluster" {
  source                 = "../../modules/clickhouse-cluster"
  name                   = "obs-prod-euw1"
  vpc_id                 = module.vpc.vpc_id
  database_subnet_ids    = module.vpc.database_subnet_ids
  security_group_id      = module.security_groups.clickhouse_sg_id
  ami_id                 = var.ami_id
  key_name               = var.key_name
  instance_type          = "r6g.2xlarge"
  shard_count            = 2
  replica_count          = 2
  data_volume_size_gb    = 2000
  data_volume_iops       = 10000
  instance_profile_name  = var.instance_profile_name
  internal_zone_id       = var.internal_zone_id

  depends_on = [module.keeper_cluster]
}

module "alb" {
  source             = "../../modules/alb"
  name               = "obs-prod-euw1"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_id  = module.security_groups.alb_sg_id
  certificate_arn    = var.certificate_arn
}
