# TaskFlow frontend image: build the React app with Node, serve it with
# unprivileged nginx (listens on 8080, runs as UID 101) which also proxies /api.
# Build context: final-devops-project/   (see ../.dockerignore)
#   docker build -f docker/frontend.Dockerfile -t taskflow-frontend:local .

# ---- stage 1: build the static bundle ---------------------------------------
FROM node:24-alpine AS build
WORKDIR /app

COPY application/frontend/package.json application/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY application/frontend/index.html application/frontend/vite.config.js ./
COPY application/frontend/public ./public
COPY application/frontend/src ./src
RUN npm run build

# ---- stage 2: runtime -------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.30-alpine

LABEL org.opencontainers.image.title="taskflow-frontend" \
      org.opencontainers.image.description="TaskFlow UI (React + Vite) on nginx-unprivileged" \
      org.opencontainers.image.source="https://github.com/Bhuvanesh66/devops-heros" \
      org.opencontainers.image.authors="Bhuvanesh M S (24bcs10134)"

# Where nginx forwards /api. The official entrypoint renders
# /etc/nginx/templates/*.template with envsubst at start-up, so the same image
# works in docker compose (http://backend:8000) and in Kubernetes
# (http://<release>-backend:8000). Only BACKEND_* variables are substituted.
# The rendered file goes to /tmp (the only writable path when the root
# filesystem is read-only) and conf.d/default.conf is a symlink to it.
ENV BACKEND_URL=http://backend:8000 \
    NGINX_ENVSUBST_FILTER=^BACKEND_ \
    NGINX_ENVSUBST_OUTPUT_DIR=/tmp

COPY docker/nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

USER root
RUN ln -sf /tmp/default.conf /etc/nginx/conf.d/default.conf
USER 101
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]
