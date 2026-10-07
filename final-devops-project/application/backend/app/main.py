"""FastAPI application: health/readiness probes, task API and Prometheus metrics."""

import logging
import time

from fastapi import Depends, FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app import __version__
from app.config import get_settings
from app.database import get_db, ping
from app.logging_config import configure_logging
from app.routers import tasks

settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger("taskflow")

# Probe and scrape requests are frequent and boring; keep them out of the request log.
QUIET_PATHS = {"/health", "/ready", "/metrics"}

app = FastAPI(
    title=settings.app_name,
    version=__version__,
    description="TaskFlow - a small task tracker used as the DevOps final project workload.",
)

if settings.cors_origin_list():
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list(),
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Content-Type"],
    )


@app.middleware("http")
async def request_log(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    if request.url.path not in QUIET_PATHS:
        logger.info(
            "request",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
            },
        )
    return response


app.include_router(tasks.router)


@app.get("/health", tags=["probes"])
def health() -> dict[str, str]:
    """Liveness: the process is up and serving HTTP. Does not touch the database."""
    return {"status": "ok", "version": __version__}


@app.get("/ready", tags=["probes"])
def ready(response: Response, db: Session = Depends(get_db)) -> dict[str, str]:
    """Readiness: only send traffic here when the database answers."""
    try:
        ping(db)
    except SQLAlchemyError as exc:
        logger.warning("readiness check failed", extra={"error": exc.__class__.__name__})
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "unavailable", "database": "unreachable"}
    return {"status": "ready", "database": "ok"}


# /metrics in Prometheus text format: http_requests_total, http_request_duration_seconds,
# http_request_duration_highr_seconds, ... plus the taskflow_* counters from app.metrics.
Instrumentator(
    should_ignore_untemplated=True,
    excluded_handlers=["/metrics"],
).instrument(app).expose(app, include_in_schema=False)
