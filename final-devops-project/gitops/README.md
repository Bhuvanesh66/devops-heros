# GitOps with Argo CD

`argocd-application.yaml` tells Argo CD to keep the namespace `taskflow`
identical to what the Helm chart renders from the `main` branch:

| Field | Value |
|---|---|
| repoURL | `https://github.com/Bhuvanesh66/devops-heros.git` |
| path | `final-devops-project/helm/taskflow` |
| valueFiles | `values-dev.yaml` |
| releaseName | `taskflow` |
| syncPolicy | automated, `prune: true`, `selfHeal: true`, `CreateNamespace=true`, retry with backoff |
| ignoreDifferences | StatefulSet `.spec.volumeClaimTemplates` (with `RespectIgnoreDifferences=true`). The API server fills in defaults on this immutable field, which otherwise leaves the app OutOfSync forever. |

## Set up

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

# values-dev.yaml enables ServiceMonitor/PrometheusRule, so install
# kube-prometheus-stack first (see monitoring/), or the sync fails on the missing CRDs.
kubectl apply -f final-devops-project/gitops/argocd-application.yaml

kubectl -n argocd get applications
kubectl -n argocd port-forward svc/argocd-server 8443:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## The GitOps workflow

1. A commit lands on `main`. The pipeline tests and scans it, builds both
   images, and pushes them to GHCR as `:<commit-sha>` and `:latest`.
2. To promote that build, I change `backend.image.tag` and `frontend.image.tag`
   in `helm/taskflow/values-dev.yaml` to the commit SHA, then commit and push.
   That change is the deployment. It is reviewed, versioned and revertible like
   any other code.
3. Argo CD notices that the desired state in Git differs from the live state
   and syncs it. The checksum annotations roll the pods.
4. **selfHeal:** a manual `kubectl scale` or `kubectl edit` in the cluster is
   reverted within a few seconds. **prune:** an object deleted from the chart
   is deleted from the cluster.
5. Rollback = `git revert` of the tag change. Argo CD syncs the old version back.

The cluster pulls from Git; CI never needs cluster credentials. That is the
main security win over the push-style `deploy` job in the pipeline, which
deploys only to a throw-away kind cluster on the runner.

<!-- SHOT: 11-argocd -->
<!-- SHOT: 11b-argocd-selfheal -->
