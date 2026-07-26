# Terraform — AWS Infrastructure

## One-time bootstrap (do this once, ever)

```bash
cd modules/s3-backend
terraform init
terraform apply -var="bucket_name=acme-observability-tfstate" -var="region=us-east-1"
```

This creates the S3 bucket + DynamoDB lock table that every environment's `backend.tf` points to.

## Deploying an environment

```bash
cd environments/prod-us-east-1
terraform init
terraform plan  -var="certificate_arn=<acm-cert-arn>" -var="internal_zone_id=<r53-zone-id>"
terraform apply -var="certificate_arn=<acm-cert-arn>" -var="internal_zone_id=<r53-zone-id>"
```

Repeat for `environments/prod-eu-west-1` for the DR region.

In practice, wire the two `-var` flags plus `key_name` / `ami_id` overrides into a `terraform.tfvars` file per environment (gitignored, or pulled from a secrets manager in CI) rather than passing on the CLI.

## What gets created

- **VPC**: 3 AZs × (public / private / database subnet), NAT per AZ.
- **EKS**: 1 cluster, 2 managed node groups (`observability-core` for Grafana/Prometheus/OTel gateway, `app-workloads` for backend/frontend, spot-priced).
- **ClickHouse**: `shard_count × replica_count` EC2 instances (default 3×2 = 6 nodes in us-east-1, 2×2 = 4 in eu-west-1), each with a dedicated io2 EBS data volume, Route53 internal DNS entries.
- **Keeper**: 3-node quorum for ClickHouse coordination.
- **ALB**: public HTTPS entrypoint, host-based routing to Grafana / frontend target groups (EKS pods register via AWS Load Balancer Controller — see `kubernetes/`).

## Sequencing changes safely

Follow the same discipline as any refactor: **plan → smallest reversible change → verify → next.**

1. `terraform plan` and read the diff. Anything showing `-/+` (replace) on `clickhouse-cluster` or `keeper-cluster` is a **destructive** change — stop and check `docs/DISASTER_RECOVERY.md` before applying.
2. Scale/instance-type changes on ClickHouse nodes: change one shard's replica set at a time (`terraform apply -target=module.clickhouse_cluster.aws_instance.clickhouse[\"s1-r1\"]`), verify replication catches up, then proceed to the next node.
3. EKS node group changes (instance type, scaling) are non-destructive rolling updates — safe to `apply` directly, `update_config.max_unavailable_percentage` caps blast radius.
4. Never `terraform destroy` a database subnet / ClickHouse module without a fresh backup verified in S3 (see `docs/DISASTER_RECOVERY.md`).

## Adding a new region / AZ

See `docs/ONBOARDING_RUNBOOK.md` § "Adding infrastructure capacity" — copy `environments/prod-eu-west-1` as a template, adjust CIDR ranges (must not overlap other regions if VPC peering/Transit Gateway is added later), and register the new ClickHouse shard set in `clickhouse/config.d/remote_servers.xml` (rendered by Ansible, not Terraform).
