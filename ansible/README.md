# Ansible — Fleet Configuration & Monitoring Target Lifecycle

## Inventory model (two sources, merged)

1. **`inventory/aws_ec2.yml`** — dynamic. Anything Terraform tags `MonitoringManaged=true` (ClickHouse/Keeper nodes) is auto-discovered. No manual edits, ever.
2. **`inventory/monitored_targets.yml`** — static, version-controlled source of truth for everything else being monitored: VMs, appliances (SNMP-only devices), golden-image instances. Edited exclusively through the onboarding/decommission playbooks (never by hand) so it can never drift from reality.

## Day-to-day: adding / removing a monitored target

```bash
# Add
./scripts/add-monitoring-target.sh -h web-app-07 -i 10.0.40.55 -t checkout-squad \
  -p "/var/log/checkout/*.log"

# Remove
./scripts/remove-monitoring-target.sh -h web-app-07
```

See `docs/ONBOARDING_RUNBOOK.md` and `docs/OFFBOARDING_RUNBOOK.md` for the full walkthrough, including flowcharts and what "add/remove" means for VMs vs. appliances vs. images.

## Fleet-wide convergence

```bash
ansible-playbook playbooks/site.yml            # all managed hosts, rolling batches
ansible-playbook playbooks/clickhouse_cluster.yml   # after Terraform changes ClickHouse/Keeper topology
```

Both are idempotent — safe to run on a schedule (e.g. nightly via CI) to correct config drift.

## Roles

| Role | Purpose |
|---|---|
| `common` | base packages, NTP (chrony), service user, directories |
| `node_exporter` | host metrics → scraped by Prometheus |
| `fluentbit` | log tailing/parsing → forwards to local OTel agent |
| `otel_collector` | local agent: receives OTLP (traces/metrics/logs), tags with host/env metadata, forwards to central gateway on EKS |
| `clickhouse` | installs ClickHouse server or Keeper depending on `clickhouse_role`, renders cluster topology from live inventory |
| `prometheus_registration` | writes/deletes a `file_sd` JSON target definition in S3 — the actual add/remove mechanism Prometheus reacts to |

## Why file_sd + S3 instead of EC2 service discovery only

EC2 SD only covers AWS-tagged instances. This fleet also needs to monitor on-prem VMs and third-party appliances that Terraform never touches. Using an S3-backed `file_sd` prefix as the single mechanism means **one uniform add/remove workflow regardless of where the target lives** — the Ansible role is the only thing that needs to know how to reach the target; Prometheus just watches a folder.

## Safety notes

- `clickhouse_cluster.yml` uses `serial: 1` on data nodes — cluster topology changes are the highest-risk operation in this whole repo. One node at a time, always wait for `/ping` to return 200 before moving to the next.
- `decommission_node.yml` deregisters from Prometheus **before** stopping agents, so there's never a window where a still-alerting target looks "down" mid-teardown.
- Decommissioning never deletes ClickHouse data — retention is TTL-driven (see `clickhouse/init-schemas/`), so a mistaken removal is fully recoverable by re-onboarding.
