# syntax=docker/dockerfile:1

# ---------- Stage 1: install production dependencies only ----------
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# npm ci = exact versions from the lockfile; no devDependencies; no install scripts.
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund \
    && npm cache clean --force

# ---------- Stage 2: minimal runtime image ----------
FROM node:22-alpine AS runtime

LABEL org.opencontainers.image.title="session17-devsecops-api" \
      org.opencontainers.image.description="Session 17 DevSecOps Notes API" \
      org.opencontainers.image.authors="Bhuvanesh M S (24bcs10134)" \
      org.opencontainers.image.source="https://github.com/Bhuvanesh66/devops-heros"

# Pick up the latest Alpine security fixes, then remove the package managers the
# app never uses at runtime (npm, npx, corepack, yarn). They ship their own
# bundled dependencies, which are a frequent source of image-scan findings.
RUN apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
              /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
              /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Files stay owned by root, so the non-root runtime user can read but not modify them.
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# Built-in non-root user from the official node image (uid 1000).
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]

CMD ["node", "src/server.js"]
