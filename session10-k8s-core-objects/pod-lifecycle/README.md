# `pod-lifecycle/` — index

Twelve manifests, each isolating **one** thing about how a Pod lives and dies. Work through
them in order; each one is meant to be run with:

```bash
kubectl apply -f <file>
kubectl get pods -w        # -w = watch, so you see the transitions live
kubectl describe pod <name>
kubectl logs <name>
```

| # | File | What it demonstrates | What you should see |
| - | ---- | -------------------- | ------------------- |
| 01 | `01-simple-pod.yaml` | The four mandatory fields, one container | `1/1 Running` |
| 02 | `02-labels-and-annotations.yaml` | Labels are selectable, annotations are not | `-l tier=backend` matches; annotations only in `describe` |
| 03 | `03-restart-policy-never.yaml` | `restartPolicy: Never`, container exits 0 | `Completed`, phase `Succeeded`, no restarts |
| 04 | `04-restart-policy-always-crash.yaml` | `restartPolicy: Always`, container exits 1 | `Error` → `CrashLoopBackOff`, RESTARTS climbing |
| 05 | `05-resources.yaml` | requests (scheduler) vs limits (kubelet) | Both visible in `describe` |
| 06 | `06-env-and-command.yaml` | `env`, the downward API, `command`/`args` | Pod name/IP/node printed in the logs |
| 07 | `07-readiness-probe.yaml` | Readiness gates **traffic**, not restarts | `0/1 Running` → `1/1 Running`, RESTARTS stays 0 |
| 08 | `08-liveness-probe.yaml` | Liveness **restarts** the container | RESTARTS goes 0 → 1, exit code 137 |
| 09 | `09-startup-probe.yaml` | Startup probe disables liveness while booting | `0/1` for ~45s then `1/1`, **no** restart |
| 10 | `10-init-container.yaml` | Init containers run to completion, in order | `Init:0/2` → `Init:1/2` → `PodInitializing` → `Running` |
| 11 | `11-multi-container.yaml` | Sidecar: shared network + shared volume | `2/2 Running`, sidecar tails the app's file |
| 12 | `12-graceful-termination.yaml` | `preStop` hook + `terminationGracePeriodSeconds` | Delete takes ~11s; `--grace-period=0 --force` takes ~0.5s |

Cleanup for the whole folder:

```bash
kubectl delete -f pod-lifecycle/
```

Full run-through with real terminal output is in the parent
[README.md](../README.md#part-1--pod-lifecycle-all-12-files).

---

## `instructor-lab/`

The class repository's own Pod-lifecycle lab (`01-running.yaml` through `12-termination.yaml` plus
its README) is kept intact in [`instructor-lab/`](instructor-lab/README.md). It covers the
same ground with different Pod names, so it is kept in a subfolder to avoid two sets of
manifests colliding in one `kubectl apply -f pod-lifecycle/`.
