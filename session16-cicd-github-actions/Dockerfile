# syntax=docker/dockerfile:1

# ---------- Stage 1: builder ----------
# Build wheels for all runtime dependencies so the final image needs no compiler or pip cache.
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---------- Stage 2: runtime ----------
FROM python:3.12-slim AS runtime

# Values passed by the CI build job (docker/build-push-action build-args).
ARG APP_VERSION=dev
ARG GIT_SHA=local

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    PORT=8000

LABEL org.opencontainers.image.title="session16-cicd-demo" \
      org.opencontainers.image.description="Session 16 CI/CD demo - unit converter API" \
      org.opencontainers.image.source="https://github.com/Bhuvanesh66/devops-heros" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

# Unprivileged user to run the app. A numeric UID lets Kubernetes verify runAsNonRoot.
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home app

WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY app/ ./app/

USER 10001

EXPOSE 8000

# Uses the Python standard library so no curl/wget is needed in the slim image.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "app.main:app"]
