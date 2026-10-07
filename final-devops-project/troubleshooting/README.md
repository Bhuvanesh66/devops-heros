# Troubleshooting challenge

Eight issues are broken into the TaskFlow stack on purpose. Each one is a small
Kustomize overlay on top of `lab-base/`, which is a working copy of
`kubernetes/` in its own namespace, `taskflow-lab`. The broken variants never
touch the real deployment in namespace `taskflow`, which Argo CD may be
self-healing.

For every issue I follow the same loop: **identify** the symptom, **investigate**
with kubectl, find the **root cause**, **fix** it, **verify** the fix, and
**document** it here.

```bash
cd final-devops-project

# 0. healthy baseline (needs the images: GHCR packages public, or minikube image load)
kubectl apply -k troubleshooting/lab-base
kubectl -n taskflow-lab get pods,svc,endpoints,hpa

# 1. break it
kubectl apply -k troubleshooting/issue-3-service-selector-mismatch

# 2. investigate ... fix ... verify, then return to the baseline
kubectl apply -k troubleshooting/lab-base

# clean up the whole lab
kubectl delete namespace taskflow-lab
```

| # | Overlay | What is broken | First visible symptom |
|---|---|---|---|
| 1 | `issue-1-wrong-image-tag` | backend image tag `v1.0.O` does not exist | `ErrImagePull` / `ImagePullBackOff` |
| 2 | `issue-2-wrong-db-host` | ConfigMap `DB_HOST=taskflow-postgresql` | `Init:Error` then `Init:CrashLoopBackOff` |
| 3 | `issue-3-service-selector-mismatch` | Service selects `component: api` | Service has no endpoints, `/api` returns 502/503 |
| 4 | `issue-4-wrong-target-port` | Service `targetPort: 8080`, app listens on 8000 | endpoints exist but connections are refused |
| 5 | `issue-5-readiness-probe-path` | readiness probe on `/readyz` (404) | pods `Running` but `0/1 READY` |
| 6 | `issue-6-missing-secret-key` | Secret key renamed to `DB_PASS` | `CreateContainerConfigError` |
| 7 | `issue-7-hpa-without-requests` | backend container has no `resources` | HPA `TARGETS` shows `<unknown>` |
| 8 | `issue-8-frontend-backend-url` | nginx proxies to `http://taskflow-api:8000` | frontend `CrashLoopBackOff` |

The general toolbox I used:

```bash
kubectl -n taskflow-lab get pods -o wide
kubectl -n taskflow-lab describe pod <pod>          # Events at the bottom
kubectl -n taskflow-lab logs <pod> [-c migrate] [--previous]
kubectl -n taskflow-lab get endpointslices -l kubernetes.io/service-name=taskflow-backend
kubectl -n taskflow-lab get events --sort-by=.lastTimestamp
kubectl -n taskflow-lab run tmp --rm -it --image=curlimages/curl:8.22.0 --restart=Never -- sh
```

---

## Issue 1 - wrong image tag

**Symptom.** New backend pods never start. `kubectl get pods` shows
`ErrImagePull`, then `ImagePullBackOff`. The old ReplicaSet keeps serving
because the rollout uses `maxUnavailable: 0`, so the app may look "fine" while
the rollout is stuck.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-1-wrong-image-tag
kubectl -n taskflow-lab get pods
kubectl -n taskflow-lab describe pod -l app.kubernetes.io/component=backend | sed -n '/Events/,$p'
kubectl -n taskflow-lab rollout status deploy/taskflow-backend --timeout=60s
kubectl -n taskflow-lab get deploy taskflow-backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Root cause, fix and verification.**

<!-- LIVE: issue-1 -->

---

## Issue 2 - wrong database host in the ConfigMap

**Symptom.** Backend pods stay in `Init:0/1`, then `Init:Error` and
`Init:CrashLoopBackOff`. The `migrate` initContainer waits for the database
(30 attempts, 2 s apart) and then exits with code 1. The frontend shows
"Could not reach the API".

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-2-wrong-db-host
kubectl -n taskflow-lab rollout restart deploy/taskflow-backend   # pick up the new ConfigMap
kubectl -n taskflow-lab get pods -w
kubectl -n taskflow-lab logs deploy/taskflow-backend -c migrate
kubectl -n taskflow-lab get configmap taskflow-config -o yaml
kubectl -n taskflow-lab get svc
```

**Root cause, fix and verification.**

<!-- LIVE: issue-2 -->

---

## Issue 3 - Service selector does not match the pods

**Symptom.** All pods are `Running` and `READY`, but every `/api` call fails:
through the Ingress it is a 503, through the frontend's nginx a 502. The
backend Service exists and has a ClusterIP, but it has no endpoints.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-3-service-selector-mismatch
kubectl -n taskflow-lab get endpointslices -l kubernetes.io/service-name=taskflow-backend
kubectl -n taskflow-lab describe svc taskflow-backend        # Selector vs Endpoints
kubectl -n taskflow-lab get pods --show-labels -l app.kubernetes.io/name=taskflow
```

**Root cause, fix and verification.**

<!-- LIVE: issue-3 -->

---

## Issue 4 - wrong targetPort

**Symptom.** The Service has endpoints, but they point at port 8080. Calls to
the Service time out or are refused, and nginx logs `connect() failed (111:
Connection refused) while connecting to upstream`.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-4-wrong-target-port
kubectl -n taskflow-lab get endpointslices -l kubernetes.io/service-name=taskflow-backend -o wide
kubectl -n taskflow-lab get svc taskflow-backend -o jsonpath='{.spec.ports}{"\n"}'
kubectl -n taskflow-lab get pod -l app.kubernetes.io/component=backend \
  -o jsonpath='{.items[0].spec.containers[0].ports}{"\n"}'
kubectl -n taskflow-lab run tmp --rm -it --image=curlimages/curl:8.22.0 --restart=Never -- \
  curl -sv --max-time 5 http://taskflow-backend:8000/health
```

**Root cause, fix and verification.**

<!-- LIVE: issue-4 -->

---

## Issue 5 - readiness probe on a path that does not exist

**Symptom.** The new backend pod is `Running` with `0/1` READY and never becomes
ready. `describe` shows `Readiness probe failed: HTTP probe failed with
statuscode: 404`. It is not restarted (only liveness failures restart a
container), it just never receives traffic, and the rollout hangs.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-5-readiness-probe-path
kubectl -n taskflow-lab get pods
kubectl -n taskflow-lab describe pod -l app.kubernetes.io/component=backend | grep -A3 -i readiness
kubectl -n taskflow-lab logs deploy/taskflow-backend | tail     # the 404s are logged as JSON
```

**Root cause, fix and verification.**

<!-- LIVE: issue-5 -->

---

## Issue 6 - Secret is missing the key the pods reference

The story: somebody recreated the Secret by hand and called the key `DB_PASS`.
To reproduce it, the old Secret has to go first, because `kubectl apply` merges
`stringData` into the existing `data` and would keep the old key:

```bash
kubectl -n taskflow-lab delete secret taskflow-db
kubectl apply -k troubleshooting/issue-6-missing-secret-key
kubectl -n taskflow-lab rollout restart deploy/taskflow-backend
```

**Symptom.** New backend pods are stuck in `CreateContainerConfigError`
(already in the `migrate` initContainer).

**How to detect.**

```bash
kubectl -n taskflow-lab get pods
kubectl -n taskflow-lab describe pod -l app.kubernetes.io/component=backend | sed -n '/Events/,$p'
kubectl -n taskflow-lab get secret taskflow-db -o jsonpath='{.data}' ; echo   # key names only matter here
```

**Root cause, fix and verification.**

<!-- LIVE: issue-6 -->

---

## Issue 7 - HPA without resource requests

**Symptom.** The application works, but the backend HPA never scales:
`kubectl get hpa` shows `cpu: <unknown>/70%` and `memory: <unknown>/80%`, and the
HPA events say `FailedGetResourceMetric ... missing request for cpu`.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-7-hpa-without-requests
kubectl -n taskflow-lab get hpa
kubectl -n taskflow-lab describe hpa taskflow-backend
kubectl -n taskflow-lab get deploy taskflow-backend -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl top pods -n taskflow-lab     # proves metrics-server itself works
```

**Root cause, fix and verification.**

<!-- LIVE: issue-7 -->

---

## Issue 8 - frontend proxies /api to a Service that does not exist

**Symptom.** Frontend pods go into `CrashLoopBackOff` right after start. The
logs end with `host not found in upstream "taskflow-api:8000"`: nginx resolves
`proxy_pass` hosts once at start-up and refuses to start when the name does not
resolve.

**How to detect.**

```bash
kubectl apply -k troubleshooting/issue-8-frontend-backend-url
kubectl -n taskflow-lab rollout restart deploy/taskflow-frontend
kubectl -n taskflow-lab get pods -l app.kubernetes.io/component=frontend
kubectl -n taskflow-lab logs deploy/taskflow-frontend --previous
kubectl -n taskflow-lab get configmap taskflow-config -o jsonpath='{.data.BACKEND_URL}{"\n"}'
kubectl -n taskflow-lab get svc
```

**Root cause, fix and verification.**

<!-- LIVE: issue-8 -->

---

## What I took away

<!-- LIVE: troubleshooting-lessons -->
