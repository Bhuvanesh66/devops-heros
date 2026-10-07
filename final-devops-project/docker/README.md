# Docker

| File | Purpose |
|---|---|
| `backend.Dockerfile` | FastAPI backend. Two stages: a builder that installs the pinned requirements into `/opt/venv`, then a slim runtime that copies only the venv and the app code. Runs as UID 10001. |
| `frontend.Dockerfile` | React frontend. Two stages: `node:24-alpine` runs `npm ci` and `vite build`, then `nginxinc/nginx-unprivileged:1.30-alpine` serves `dist/`. Runs as UID 101 on port 8080. |
| `nginx.conf` | The nginx server block, installed as a template. It serves the single-page app and proxies `/api/` to `${BACKEND_URL}`. |
| `docker-compose.yml` | The whole stack (PostgreSQL 17, backend, frontend) with one command. |
| `.env.example` | Optional overrides for the compose defaults (database name, user and password). |

## Build context

I keep the Dockerfiles in this folder and use **`final-devops-project/` as the
build context** for both images. That way the frontend image can copy
`docker/nginx.conf` and the app code from `application/frontend/` in one
build. `../.dockerignore` is an allow-list, so the daemon only receives the
files the images need. Tests, `node_modules`, `.env` files and reports are
never sent.

```bash
cd final-devops-project
docker build -f docker/backend.Dockerfile  -t taskflow-backend:local  .
docker build -f docker/frontend.Dockerfile -t taskflow-frontend:local .
```

## Run the stack

```bash
cd final-devops-project/docker
docker compose up --build
```

| URL | What |
|---|---|
| http://localhost:3000 | TaskFlow UI (nginx). `/api/*` is proxied to the backend. |
| http://localhost:8000/docs | FastAPI Swagger UI |
| http://localhost:8000/health, `/ready`, `/metrics` | probes and Prometheus metrics |

Start-up order is handled with health checks. PostgreSQL has to pass
`pg_isready` before the backend starts. The backend runs
`python -m app.prestart`, which waits for the database and runs
`alembic upgrade head`, then starts uvicorn. The frontend only starts once the
backend's `/health` check passes.

## How the backend URL is configured

The frontend always calls `/api/...` on its own origin, so the browser never
needs to know where the backend is and CORS is not needed. nginx forwards
`/api/` to `BACKEND_URL`. The official nginx entrypoint renders
`/etc/nginx/templates/default.conf.template` with `envsubst` at start-up, and
`NGINX_ENVSUBST_FILTER=^BACKEND_` restricts it to `BACKEND_*` variables, so
nginx's own `$host`, `$uri` and other variables are left alone.

| Where | `BACKEND_URL` |
|---|---|
| docker compose | `http://backend:8000` (compose service name) |
| Kubernetes, plain manifests | `http://taskflow-backend:8000` (ConfigMap `taskflow-config`) |
| Helm | `http://<release>-backend:8000` (generated in the chart's ConfigMap) |

## Hardening

- Both images run as non-root users with fixed UIDs (10001 and 101).
- `pip` is removed from the backend runtime venv, and the image contains no compilers.
- In compose, both app containers are `read_only` with a `tmpfs` for `/tmp`.
  The nginx template is rendered into `/tmp/default.conf`, and
  `/etc/nginx/conf.d/default.conf` is a symlink to it, so nothing else needs to
  be writable. They also use `cap_drop: [ALL]` and `no-new-privileges`.
- `HEALTHCHECK` is defined in both images (`/health` and `/healthz`).

<!-- SHOT: 02-compose-up -->
