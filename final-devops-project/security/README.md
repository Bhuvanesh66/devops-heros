# Security (DevSecOps)

| File | Used by | What it does |
|---|---|---|
| `semgrep-rules.yml` | SAST job | custom Python rules: SQL built into `text()`, hard-coded DB URL credentials, credential-named literals, `shell=True` / `os.system`, `eval`/`exec`, CORS `*` with credentials, uvicorn reload/debug |
| `bandit.yaml` | SAST job | Bandit config. All checks enabled, tests excluded |
| `.gitleaks.toml` | secret-scan job | full default Gitleaks rule set + allow-list of generated paths only |
| `.gitleaksignore` | secret-scan job | reviewed and accepted findings (empty) |
| `.trivyignore` | SCA + image scan | reviewed and accepted CVEs (empty) |
| `gate.py` | security-gate job | **the single PASS/FAIL decision**. Reads every report and applies the policy below |
| `scan-local.sh` | me, locally | runs the same scans with Docker and then the same gate |

## Policy (security/gate.py)

| Stage | Tool | Blocks the pipeline when |
|---|---|---|
| SAST | Semgrep (p/python, p/javascript, p/dockerfile, custom rules) | any finding with severity ERROR, or any Semgrep run error |
| SAST | Bandit | any HIGH severity issue with MEDIUM or HIGH confidence |
| SCA | pip-audit | any known vulnerability in `requirements.txt` |
| SCA | npm audit | any HIGH or CRITICAL advisory in `package-lock.json` |
| SCA | Trivy fs | any HIGH or CRITICAL vulnerability with a fix |
| Secrets | Gitleaks (files + git history of this folder) | any secret at all |
| Image | Trivy image (backend and frontend) | any HIGH/CRITICAL vulnerability with a fix, or an embedded secret |
| Any | | a report is missing or unreadable (the scan did not run) |

The scanners themselves always exit 0 and only write reports. That keeps one
red job from hiding the results of the others, and the gate summary shows
every scanner side by side. If the gate fails, `push-images` and `deploy` do
not run.

## Run locally

```bash
cd final-devops-project
bash security/scan-local.sh                 # everything, including image builds
SKIP_IMAGES=1 bash security/scan-local.sh   # source scans only (the gate then fails on the missing image reports)
```

Lesson carried over from session 17: Trivy and some other tools do not create
missing parent directories for their `--output`, and `reports/` is
git-ignored, so every job runs `mkdir -p reports` before the tools run. In
documentation I also never paste anything that looks like a real key, not even
a fake one, because Gitleaks scans the history too.

<!-- SHOT: 05-security-gate -->
