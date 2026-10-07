#!/bin/sh
# Container entrypoint for the TaskFlow backend.
#   RUN_MIGRATIONS=true  (default, docker compose): wait for the DB, alembic upgrade head, then serve.
#   RUN_MIGRATIONS=false (Kubernetes): an initContainer already ran `python -m app.prestart`.
set -eu

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  python -m app.prestart
fi

exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "${PORT:-8000}" \
  --proxy-headers \
  --forwarded-allow-ips "*" \
  --no-server-header
