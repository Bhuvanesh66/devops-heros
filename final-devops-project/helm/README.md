# Helm chart: `taskflow`

`helm/taskflow` packages the whole application: PostgreSQL StatefulSet with a
PVC, backend and frontend Deployments and Services, ConfigMap, Secret, Ingress,
HPAs, and an optional ServiceMonitor, PrometheusRule and Grafana dashboard
ConfigMap. It also includes a `helm test` hook.

| Values file | Used for |
|---|---|
| `values.yaml` | defaults. Monitoring objects are off, and `database.password` must be supplied |
| `values-dev.yaml` | minikube/kind and **Argo CD** (`gitops/argocd-application.yaml`). Demo-only DB password, monitoring objects on, 2-4 replicas |
| `values-prod.yaml` | `existingSecret` for DB credentials, 3+ replicas, bigger requests, 10Gi PVC, TLS Ingress, image pull secret |

## Install

```bash
cd final-devops-project
helm lint helm/taskflow -f helm/taskflow/values-dev.yaml
helm template taskflow helm/taskflow -f helm/taskflow/values-dev.yaml | less

# dev (needs the Prometheus Operator CRDs because values-dev enables the
# ServiceMonitor/PrometheusRule; add --set serviceMonitor.enabled=false,prometheusRule.enabled=false otherwise)
helm upgrade --install taskflow helm/taskflow -n taskflow --create-namespace \
  -f helm/taskflow/values-dev.yaml \
  --set backend.image.tag=<commit-sha> --set frontend.image.tag=<commit-sha>

helm list -n taskflow
helm test taskflow -n taskflow --logs
helm history taskflow -n taskflow
helm rollback taskflow 1 -n taskflow
```

With release name `taskflow`, the objects are called `taskflow-backend`,
`taskflow-frontend`, `taskflow-postgres`, `taskflow-config` and `taskflow-db`,
the same names as the plain manifests.

## Things worth pointing out

- **Checksum annotations.** `checksum/config` and `checksum/secret` on the pod
  templates change whenever the rendered ConfigMap or Secret changes, so
  `helm upgrade` rolls the pods. A plain `kubectl apply` of a ConfigMap does
  not do that.
- **The password is required.** Without `database.password` or
  `database.existingSecret` the chart refuses to render. That is deliberate:
  there is no silent default password. CI passes a random one
  (`openssl rand -hex 16`).
- **HPA and replicas.** When autoscaling is enabled, `spec.replicas` is left
  out of the Deployment, so `helm upgrade` and Argo CD never fight the HPA.
- **Monitoring toggles.** `serviceMonitor.enabled`, `prometheusRule.enabled`
  and `grafanaDashboard.enabled` render the Prometheus Operator objects. The
  dashboard JSON is `files/taskflow-dashboard.json`, the same file as
  `monitoring/grafana-dashboard.json` (CI checks this).

<!-- SHOT: 07-helm-release -->
