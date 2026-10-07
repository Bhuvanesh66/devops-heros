#!/usr/bin/env bash
# Run every security scan of the pipeline locally and evaluate the same
# security gate GitHub Actions uses. Needs Docker; Python 3.12 and Node are
# used from the host when present, otherwise from throw-away containers.
#
#   cd final-devops-project
#   bash security/scan-local.sh            # all scans, images built locally
#   SKIP_IMAGES=1 bash security/scan-local.sh   # source scans only
#
# Reports land in ./reports (git-ignored).
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"

SEMGREP_IMAGE="semgrep/semgrep:1.179.0"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
TRIVY_IMAGE="aquasec/trivy:0.75.0"
PYTHON_IMAGE="python:3.12-slim"
NODE_IMAGE="node:24-alpine"
BACKEND_IMAGE="${BACKEND_IMAGE:-taskflow-backend:scan}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-taskflow-frontend:scan}"

mkdir -p reports

run_python() {
  if command -v python3 > /dev/null 2>&1; then
    sh -c "$1"
  else
    docker run --rm -v "$PROJECT_DIR:/p" -w /p "$PYTHON_IMAGE" sh -c "$1"
  fi
}

run_node() {
  if command -v npm > /dev/null 2>&1; then
    (cd application/frontend && sh -c "$1")
  else
    docker run --rm -v "$PROJECT_DIR/application/frontend:/app" -w /app "$NODE_IMAGE" sh -c "$1"
  fi
}

trivy() {
  docker run --rm \
    -v trivy-cache:/root/.cache/trivy \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_DIR:/src" -w /src \
    "$TRIVY_IMAGE" "$@"
}

echo "==> [1/7] SAST - Semgrep (registry rules + security/semgrep-rules.yml)"
docker run --rm -v "$PROJECT_DIR:/src" -w /src "$SEMGREP_IMAGE" \
  semgrep scan --metrics=off \
    --config p/python --config p/javascript --config p/dockerfile \
    --config security/semgrep-rules.yml \
    --exclude node_modules --exclude dist --exclude reports --exclude .terraform \
    --json-output reports/semgrep.json .

echo "==> [2/7] SAST - Bandit"
run_python "python3 -m pip install -q bandit==1.9.4 && python3 -m bandit -c security/bandit.yaml -r application/backend -f json -o reports/bandit.json --exit-zero && python3 -m bandit -c security/bandit.yaml -r application/backend --exit-zero -q"

echo "==> [3/7] SCA - pip-audit (backend requirements)"
run_python "python3 -m pip install -q pip-audit==2.10.1 && python3 -m pip_audit -r application/backend/requirements.txt -f json -o reports/pip-audit.json || true; python3 -m pip_audit -r application/backend/requirements.txt || true"

echo "==> [4/7] SCA - npm audit (frontend lockfile)"
run_node "npm audit --json > ../../reports/npm-audit.json || true; npm audit --audit-level=high || true"

echo "==> [5/7] SCA - Trivy filesystem scan"
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
  --ignorefile security/.trivyignore --skip-dirs application/frontend/node_modules \
  --format json --output reports/trivy-fs.json --exit-code 0 .

echo "==> [6/7] Secret scan - Gitleaks (current files)"
docker run --rm -v "$PROJECT_DIR:/repo" "$GITLEAKS_IMAGE" dir /repo \
  --config /repo/security/.gitleaks.toml \
  --report-format json --report-path /repo/reports/gitleaks-dir.json \
  --redact --verbose --no-banner --exit-code 0

if [ -z "${SKIP_IMAGES:-}" ]; then
  echo "==> [7/7] Build images + Trivy image scans + SBOM"
  docker build -f docker/backend.Dockerfile -t "$BACKEND_IMAGE" .
  docker build -f docker/frontend.Dockerfile -t "$FRONTEND_IMAGE" .
  for pair in "backend:$BACKEND_IMAGE" "frontend:$FRONTEND_IMAGE"; do
    name="${pair%%:*}"
    image="${pair#*:}"
    trivy image --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed \
      --ignorefile security/.trivyignore \
      --format json --output "reports/trivy-image-$name.json" --exit-code 0 "$image"
    trivy image --format cyclonedx --output "reports/sbom-$name.cdx.json" --quiet "$image"
  done
else
  echo "==> [7/7] image scans skipped (SKIP_IMAGES set) - the gate will report them as missing"
fi

echo "==> Security gate"
run_python "python3 security/gate.py reports"
