# TaskFlow backend image (FastAPI + Alembic).
# Build context: final-devops-project/   (see ../.dockerignore)
#   docker build -f docker/backend.Dockerfile -t taskflow-backend:local .

# ---- stage 1: install dependencies into a virtualenv ------------------------
FROM python:3.12-slim-trixie AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY application/backend/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt \
 # pip is not needed at runtime; removing it shrinks the image and the scan surface
 && pip uninstall -y pip

# ---- stage 2: runtime ---------------------------------------------------------
FROM python:3.12-slim-trixie

LABEL org.opencontainers.image.title="taskflow-backend" \
      org.opencontainers.image.description="TaskFlow API (FastAPI, SQLAlchemy, Alembic)" \
      org.opencontainers.image.source="https://github.com/Bhuvanesh66/devops-heros" \
      org.opencontainers.image.authors="Bhuvanesh M S (24bcs10134)"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}" \
    PORT=8000 \
    RUN_MIGRATIONS=true

# Fixed, non-root UID/GID so Kubernetes runAsUser/runAsNonRoot can match it.
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY application/backend/alembic.ini application/backend/start.sh ./
COPY application/backend/alembic ./alembic
COPY application/backend/app ./app
# Strip CR in case the file was checked out with Windows line endings.
RUN sed -i 's/\r$//' start.sh && chmod 0755 start.sh

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["./start.sh"]
