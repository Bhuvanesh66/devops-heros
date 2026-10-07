# Monitoring and logs

| File | What |
|---|---|
| `kube-prometheus-stack-values.yaml` | Helm values for Prometheus + Alertmanager + Grafana + kube-state-metrics + node-exporter, sized for minikube. Selects ServiceMonitors and rules from all namespaces. The Grafana sidecar loads dashboards from all namespaces |
| `servicemonitor.yaml` | scrape `taskflow-backend:8000/metrics` every 15 s (plain-manifest deployment) |
| `prometheus-rules.yaml` | alerts: backend down, 5xx ratio > 5 %, p95 latency > 0.5 s, pod restarts, HPA at max replicas |
| `grafana-dashboard.json` | the TaskFlow dashboard (12 panels) |
| `grafana-dashboard-configmap.yaml` | the same JSON in a ConfigMap labelled `grafana_dashboard: "1"` |

With Helm, set `serviceMonitor.enabled`, `prometheusRule.enabled` and
`grafanaDashboard.enabled` to `true`. `values-dev.yaml` already does. The chart
then renders the same three objects for its release, so the files here are
only needed for the plain-manifest deployment.

## Metrics the backend exposes (`GET /metrics`)

| Metric | Source | Labels |
|---|---|---|
| `http_requests_total` | prometheus-fastapi-instrumentator | `handler`, `method`, `status` (`2xx`/`4xx`/`5xx`) |
| `http_request_duration_seconds` | instrumentator (coarse buckets) | `handler`, `method` |
| `http_request_duration_highr_seconds` | instrumentator (fine buckets, used for p50/p95/p99) | none |
| `http_request_size_bytes`, `http_response_size_bytes` | instrumentator | `handler` |
| `taskflow_tasks_created_total` | app (`app/metrics.py`) | `priority` |
| `taskflow_tasks_completed_total`, `taskflow_tasks_deleted_total` | app | none |
| `process_*`, `python_gc_*` | prometheus_client defaults | none |

## Install and wire up

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f final-devops-project/monitoring/kube-prometheus-stack-values.yaml

# plain-manifest deployment only (Helm/Argo CD render these themselves):
kubectl apply -f final-devops-project/monitoring/servicemonitor.yaml
kubectl apply -f final-devops-project/monitoring/prometheus-rules.yaml
kubectl apply -f final-devops-project/monitoring/grafana-dashboard-configmap.yaml

kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090   # Status -> Targets: taskflow-backend UP
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80        # Dashboards -> "TaskFlow - Application Overview"
```

Generate some traffic so the panels have data:

```bash
kubectl -n taskflow port-forward svc/taskflow-backend 8000:8000 &
for i in $(seq 1 200); do
  curl -s -X POST localhost:8000/api/tasks -H 'Content-Type: application/json' -d "{\"title\":\"load $i\"}" > /dev/null
  curl -s localhost:8000/api/tasks > /dev/null
  curl -s localhost:8000/api/tasks/999999 > /dev/null   # 404s show up as 4xx
done
```

## Logs

The backend writes one JSON object per line to stdout. Every request is
logged with method, path, status and duration. Probe and scrape requests are
left out so they do not drown the useful lines.

```bash
kubectl -n taskflow logs deploy/taskflow-backend -f
kubectl -n taskflow logs deploy/taskflow-backend -c migrate     # migration output
```

With Loki and Alloy from session 20 installed, the same lines can be queried
in Grafana Explore:

```logql
{namespace="taskflow", container="backend"} | json | status >= 400
```

<!-- SHOT: 09-grafana -->
<!-- SHOT: 10-prometheus-alerts -->
<!-- SHOT: 16-prometheus-targets -->
<!-- SHOT: 17-metrics-endpoint -->
