#!/usr/bin/env bash
# Run every security scan of the pipeline locally (only Docker is required)
# and evaluate the same security gate that GitHub Actions uses.
#
#   cd session17-devsecops-pipeline
#   bash security/scan-local.sh
#
# Reports are written to ./reports (git-ignored).
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${IMAGE:-session17-devsecops-api:local}"
SEMGREP_IMAGE="semgrep/semgrep:1.179.0"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
TRIVY_IMAGE="aquasec/trivy:0.75.0"
NODE_IMAGE="node:22-alpine"

mkdir -p reports

# Use the local Node.js when installed, otherwise a throwaway Node container.
run_node() {
  if command -v node > /dev/null 2>&1; then
    "$@"
  else
    docker run --rm -v "$PWD:/app" -w /app "$NODE_IMAGE" "$@"
  fi
}

trivy() {
  docker run --rm \
    -v trivy-cache:/root/.cache/trivy \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PWD:/src" -w /src \
    "$TRIVY_IMAGE" "$@"
}

echo "==> [1/6] SAST - Semgrep (p/javascript + p/nodejsscan + custom rules)"
docker run --rm -v "$PWD:/src" -w /src "$SEMGREP_IMAGE" \
  semgrep scan --metrics=off \
    --config p/javascript --config p/nodejsscan --config security/semgrep-rules.yml \
    --json-output reports/semgrep.json --sarif-output reports/semgrep.sarif .

echo "==> [2/6] SCA - npm audit"
run_node sh -c 'npm audit --json > reports/npm-audit.json || true; npm audit --audit-level=high || true'

echo "==> [3/6] SCA - Trivy filesystem scan"
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
  --ignorefile security/.trivyignore --skip-dirs node_modules --skip-dirs dist --skip-dirs coverage \
  --format json --output reports/trivy-fs.json --exit-code 0 .
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
  --ignorefile security/.trivyignore --skip-dirs node_modules --skip-dirs dist --skip-dirs coverage --quiet --exit-code 0 .

echo "==> [4/6] Secret scan - Gitleaks (current files)"
docker run --rm -v "$PWD:/repo" "$GITLEAKS_IMAGE" dir /repo \
  --config /repo/security/.gitleaks.toml \
  --report-format json --report-path /repo/reports/gitleaks-dir.json \
  --redact --verbose --no-banner --exit-code 0

echo "==> [5/6] Docker build + Trivy image scan + SBOM"
docker build -t "$IMAGE" .
trivy image --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed \
  --ignorefile security/.trivyignore \
  --format json --output reports/trivy-image.json --exit-code 0 "$IMAGE"
trivy image --scanners vuln,secret --ignorefile security/.trivyignore --quiet --exit-code 0 "$IMAGE"
trivy image --format cyclonedx --output reports/sbom.cdx.json --quiet "$IMAGE"

echo "==> [6/6] Security gate"
run_node node security/gate.js reports
