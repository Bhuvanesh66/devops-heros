"""Wait for the database, then run the Alembic migrations.

Used as `python -m app.prestart`:
  - by the container entrypoint (docker compose), before uvicorn starts;
  - by the Kubernetes initContainer `migrate`, so the app container only serves.

Several replicas may run this at the same time. On PostgreSQL alembic/env.py
takes an advisory lock, so only one of them migrates and the others wait.
"""

import logging
import os
import sys
import time
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy.exc import OperationalError

from app.config import get_settings
from app.database import SessionLocal, ping
from app.logging_config import configure_logging

logger = logging.getLogger("taskflow.prestart")
BACKEND_DIR = Path(__file__).resolve().parent.parent


def wait_for_db(attempts: int, delay: float) -> None:
    for attempt in range(1, attempts + 1):
        try:
            with SessionLocal() as db:
                ping(db)
            logger.info("database is reachable", extra={"attempt": attempt})
            return
        except OperationalError as exc:
            logger.warning(
                "database not reachable yet",
                extra={"attempt": attempt, "of": attempts, "error": str(exc.orig)[:200]},
            )
            time.sleep(delay)
    logger.error("database never became reachable, giving up")
    sys.exit(1)


def migrate() -> None:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    # Keep the JSON logging set up by the app instead of alembic.ini's text format.
    cfg.attributes["configure_logger"] = False
    command.upgrade(cfg, "head")
    logger.info("migrations applied (alembic upgrade head)")


def main() -> None:
    configure_logging(get_settings().log_level)
    wait_for_db(
        attempts=int(os.getenv("DB_WAIT_ATTEMPTS", "30")),
        delay=float(os.getenv("DB_WAIT_DELAY", "2")),
    )
    migrate()


if __name__ == "__main__":
    main()
