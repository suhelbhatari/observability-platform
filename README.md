# Industrial-Grade Observability Platform (AWS)

Production observability stack for **100+ hosts, multi-region/multi-AZ**, built on:

| Layer | Tech |
|---|---|
| Metrics | Prometheus (kube-prometheus-stack) + Thanos-style long-term store via ClickHouse |
| Logs | Fluent Bit (agent) → OTel Collector (gateway) → ClickHouse |
| Traces | OTel SDK → OTel Collector → ClickHouse |
| Storage | ClickHouse cluster (sharded + replicated, ClickHouse Keeper for coordination) |
| Visualization | Grafana |
| App layer | Frontend (React, on EKS) + Backend (API, on EKS) — both instrumented with OTel |
| Compute | **Mixed**: EC2 (stateful — ClickHouse, Keeper) + EKS (stateless — Grafana, Prometheus, OTel Gateway, backend, frontend) |
| IaC | Terraform (infra) + Ansible (EC2 fleet config/lifecycle) |
| Regions | `us-east-1` (primary), `eu-west-1` (DR / secondary read replica) |

## Repo layout

```
observability-platform/
├── terraform/            # AWS infra: VPC, EKS, EC2 ASGs, SGs, ALB, ClickHouse/Keeper nodes
│   ├── modules/           # Reusable modules
│   └── environments/       # Per-region/env root modules (prod-us-east-1, prod-eu-west-1)
├── ansible/               # Config management + monitored-target lifecycle
│   ├── inventory/          # Dynamic AWS EC2 inventory
│   ├── roles/              # common, node_exporter, fluentbit, otel_collector, clickhouse, prometheus_registration
│   └── playbooks/          # site.yml, onboard_node.yml, decommission_node.yml, ...
├── kubernetes/            # Helm values / manifests for EKS-hosted stateless components
├── clickhouse/            # Cluster config, users, retention (TTL), schema DDL for logs/traces/metrics
├── scripts/               # add-monitoring-target.sh / remove-monitoring-target.sh (human-friendly wrappers)
└── docs/                  # Architecture, runbooks, algorithms, flowcharts (Mermaid), DR plan
```

## Start here

1. Read `docs/ARCHITECTURE.md` for the system design and data flow diagrams.
2. Read `docs/ONBOARDING_RUNBOOK.md` before adding any new host/app/appliance to monitoring.
3. Read `docs/OFFBOARDING_RUNBOOK.md` before decommissioning anything.
4. Terraform bootstrap: `terraform/environments/prod-us-east-1/README` (bootstraps remote state, VPC, EKS, ClickHouse ASGs).
5. Ansible fleet management: `ansible/README.md`.

## Design principles applied

- **Separation of stateful vs stateless**: ClickHouse/Keeper live on EC2 with EBS + instance store (predictable disk I/O, no CSI surprises at this scale); everything stateless runs on EKS and can be redeployed/scaled freely.
- **Multi-AZ everywhere, multi-region for DR**: every ASG/EKS nodegroup spans ≥3 AZs; `eu-west-1` holds a replicated ClickHouse shard set + Grafana/Prometheus HA pair for failover.
- **Everything is code**: no manual console changes. Terraform for infra, Ansible for config + fleet membership, Helm for K8s workloads.
- **Onboarding/offboarding a monitored target is a single command**, backed by an idempotent Ansible playbook — not a manual checklist.
