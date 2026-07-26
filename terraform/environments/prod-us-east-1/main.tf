module "vpc" {
  source = "../../modules/vpc"

  name                   = "obs-prod-use1"
  cidr_block             = "10.0.0.0/16"
  azs                    = var.azs
  public_subnet_cidrs    = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
  private_subnet_cidrs   = ["10.0.32.0/20", "10.0.48.0/20", "10.0.64.0/20"]
  database_subnet_cidrs  = ["10.0.128.0/24", "10.0.129.0/24", "10.0.130.0/24"]
}

module "security_groups" {
  source = "../../modules/security-groups"

  name     = "obs-prod-use1"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = "10.0.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  name               = "obs-prod-use1"
  cluster_version    = "1.30"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  nodes_sg_id        = module.security_groups.eks_nodes_sg_id

  node_groups = {
    # Grafana, kube-prometheus-stack, OTel gateway - general purpose
    "observability-core" = {
      instance_types = ["m6i.xlarge"]
      min_size       = 3
      max_size       = 9
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
      labels         = { workload = "observability-core" }
      taints         = []
    }
    # backend + frontend apps
    "app-workloads" = {
      instance_types = ["m6i.large"]
      min_size       = 3
      max_size       = 20
      desired_size   = 4
      capacity_type  = "SPOT"
      labels         = { workload = "app" }
      taints         = []
    }
  }
}

module "keeper_cluster" {
  source = "../../modules/keeper-cluster"

  name                   = "obs-prod-use1"
  database_subnet_ids    = module.vpc.database_subnet_ids
  security_group_id      = module.security_groups.clickhouse_sg_id
  ami_id                 = var.ami_id
  key_name               = var.key_name
  node_count             = 3
  instance_profile_name  = var.instance_profile_name
  internal_zone_id       = var.internal_zone_id
}

module "clickhouse_cluster" {
  source = "../../modules/clickhouse-cluster"

  name                   = "obs-prod-use1"
  vpc_id                 = module.vpc.vpc_id
  database_subnet_ids    = module.vpc.database_subnet_ids
  security_group_id      = module.security_groups.clickhouse_sg_id
  ami_id                 = var.ami_id
  key_name               = var.key_name
  instance_type          = "r6g.2xlarge"
  shard_count            = 3
  replica_count           = 2
  data_volume_size_gb    = 2000
  data_volume_iops       = 10000
  instance_profile_name  = var.instance_profile_name
  internal_zone_id       = var.internal_zone_id

  depends_on = [module.keeper_cluster]
}

module "alb" {
  source = "../../modules/alb"

  name              = "obs-prod-use1"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_sg_id
  certificate_arn   = var.certificate_arn
}
