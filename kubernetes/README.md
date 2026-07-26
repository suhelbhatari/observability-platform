# Kubernetes (EKS) — Stateless Workloads

Deployed via Helm + plain manifests onto the `observability-core` and `app-workloads` EKS node groups created by Terraform.

## Deploy order

```bash
kubectl apply -f namespaces/namespaces.yaml

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n observability -f prometheus/values.yaml

helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  -n observability -f otel-collector-gateway/values.yaml

helm upgrade --install grafana grafana/grafana \
  -n observability -f grafana/values.yaml

kubectl apply -f backend/deployment.yaml
kubectl apply -f frontend/deployment.yaml
```

## Data flow

```
[backend/frontend pods] --OTLP--> [otel-gateway] --native TCP--> [ClickHouse cluster]
[EC2 fleet: fluent-bit -> otel-agent] --OTLP--> [otel-gateway] --native TCP--> [ClickHouse cluster]
[Prometheus] --file_sd (S3-synced)--> scrapes [node_exporter / ClickHouse /metrics]
[Prometheus] --remote_write--> [otel-gateway] --> [ClickHouse]
[Grafana] --SQL-------------------------------> [ClickHouse]  (dashboards)
[Grafana] --PromQL----------------------------> [Prometheus]  (real-time/alerting dashboards)
```

`otel-gateway` is the **single write path** into ClickHouse — nothing else is granted `INSERT` on the `otel` database. This keeps credential distribution simple and gives one place to enforce sampling/batching/backpressure.

## Grafana dashboards

Three pre-built dashboards live in `grafana/dashboards/` and auto-provision into the "Observability Platform" folder:

| Dashboard | Data source | Covers |
|---|---|---|
| `fleet-overview.json` | Prometheus | Targets up/down, fleet CPU/mem/disk/network, backend/frontend replica & restart counts, OTel Gateway throughput and export failures |
| `clickhouse-cluster-health.json` | ClickHouse (system tables) | Replica lag, read-only replicas, active merges, replication queue depth, disk usage per table/node, query rate, p95 query latency, failed queries |
| `logs-traces-overview.json` | ClickHouse (`otel.logs` / `otel.traces`) | Log volume/severity by service, top error messages, live log stream, trace volume, p50/p95/p99 span duration by service, slowest traces |

Provision them:

```bash
kubectl create configmap grafana-dashboards-observability-platform \
  -n observability \
  --from-file=grafana/dashboards/

helm upgrade --install grafana grafana/grafana -n observability -f grafana/values.yaml
```

The `dashboardsConfigMaps` + `dashboardProviders` blocks in `grafana/values.yaml` mount this ConfigMap and point Grafana's file-based dashboard provisioner at it — no manual import through the UI needed. Because the datasource `uid`s (`prometheus`, `clickhouse-metrics`, `clickhouse-logs`) are pinned in `values.yaml` rather than auto-generated, the dashboard JSON's datasource references resolve correctly on first load.

**Updating a dashboard**: edit the JSON, re-run the `kubectl create configmap ... --from-file` command with `--dry-run=client -o yaml | kubectl apply -f -` to update in place — Grafana's provisioner picks up ConfigMap changes within `updateIntervalSeconds` (30s), no restart needed.

**Adding a new dashboard**: drop a new `.json` file into `grafana/dashboards/`, re-create the ConfigMap the same way. Keep the `uid` field unique per dashboard and reuse the same three datasource `uid` values above for consistency.

## Notes for juniors

- `otel-gateway` autoscales 3→12 replicas on CPU. If ClickHouse ingestion starts lagging under load, check gateway pod count and ClickHouse `system.merges` / disk I/O before assuming the gateway itself is the bottleneck.
- Backend/frontend pods get OTel auto-instrumented via the `instrumentation.opentelemetry.io/inject-sdk` annotation (requires the OTel Operator installed separately — not included here, add via `open-telemetry/opentelemetry-operator` chart if not already present).
- Grafana talks to ClickHouse for **historical** dashboards (logs/traces/long-range metrics) and to Prometheus directly for **real-time** dashboards and alerting rules (lower latency, no ingestion lag).
