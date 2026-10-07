# Kubernetes (plain manifests)

The same objects the Helm chart creates, written out by hand. Use **either**
these manifests **or** the Helm chart in a namespace, not both, because the
object names are the same.

| File | Objects |
|---|---|
| `namespace.yaml` | Namespace `taskflow` (Pod Security: enforce `baseline`, warn `restricted`) |
| `configmap.yaml` | ConfigMap `taskflow-config`: `DB_HOST`, `DB_PORT`, `DB_NAME`, `LOG_LEVEL`, `RUN_MIGRATIONS=false`, `BACKEND_URL` |
| `secret.yaml` | Secret `taskflow-db` with `DB_USER` / `DB_PASSWORD`. **Demo-only placeholder values** |
| `postgres.yaml` | headless Service + StatefulSet `taskflow-postgres` with a 1Gi PVC (`volumeClaimTemplates`) |
| `backend.yaml` | Deployment (2 replicas, `migrate` initContainer, startup/liveness/readiness probes, requests/limits) + ClusterIP Service on 8000 |
| `frontend.yaml` | Deployment (2 replicas, probes, requests/limits) + ClusterIP Service 80 -> 8080 |
| `ingress.yaml` | Ingress `taskflow.local`: `/api` -> backend, `/` -> frontend (`ingressClassName: nginx`) |
| `hpa.yaml` | `autoscaling/v2` HPAs: backend 2-6 (CPU 70 %, memory 80 %), frontend 2-4 (CPU 75 %) |
| `kustomization.yaml` | ties it together, sets the namespace and the image tags |

## Deploy on minikube

```bash
minikube addons enable ingress
minikube addons enable metrics-server

# For anything except a throw-away cluster, create the Secret yourself and
# remove secret.yaml from kustomization.yaml:
kubectl create namespace taskflow
kubectl -n taskflow create secret generic taskflow-db \
  --from-literal=DB_USER=taskflow \
  --from-literal=DB_PASSWORD="$(openssl rand -base64 24)"

kubectl apply -k final-devops-project/kubernetes
kubectl -n taskflow get pods,svc,pvc,hpa,ingress
kubectl -n taskflow rollout status deploy/taskflow-backend

# hosts file: <minikube ip>  taskflow.local
curl http://taskflow.local/api/tasks
```

To pin a release, set `newTag` in `kustomization.yaml` to the commit SHA that CI
pushed to GHCR. The GHCR packages are private until they are made public in the
package settings. Until then, either create an image pull secret or load the
images into the node:

```bash
minikube image load ghcr.io/bhuvanesh66/final-taskflow-backend:<tag>
minikube image load ghcr.io/bhuvanesh66/final-taskflow-frontend:<tag>
```

## Design notes

- **Probes.** The startup probe (`/health`, up to 60 s) protects slow starts.
  Liveness (`/health`) only restarts a process that has stopped answering, and
  it does not check the database, so a database outage does not restart every
  pod. Readiness (`/ready`) runs `SELECT 1` and takes the pod out of the Service
  while the database is unreachable.
- **Migrations.** These run once per pod in the `migrate` initContainer
  (`python -m app.prestart`). `alembic/env.py` takes a PostgreSQL advisory lock
  first, so several replicas starting at the same time cannot run the
  migration twice.
- **Security context.** Every pod sets `runAsNonRoot`, uses a fixed UID,
  `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false` and drops
  all capabilities. The backend and frontend also run with
  `readOnlyRootFilesystem` and an `emptyDir` volume for `/tmp`.
- **HPA.** Utilization is measured against the requests, so every container
  an HPA targets has CPU and memory requests. Issue 7 of the troubleshooting
  challenge shows what happens without them.

<!-- SHOT: 06-k8s-resources -->
<!-- SHOT: 08-hpa -->
