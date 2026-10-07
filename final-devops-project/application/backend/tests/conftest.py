"""Test fixtures.

The tests never touch PostgreSQL. Before the app is imported, DATABASE_URL is
pointed at a throw-away SQLite file in a temp directory; the schema is created by
running the real Alembic migration against it (so the migration is tested too),
and every test starts with an empty `tasks` table.
"""

import os
import tempfile
from pathlib import Path

import pytest

_TMP_DIR = tempfile.mkdtemp(prefix="taskflow-tests-")
TEST_DB = Path(_TMP_DIR) / "test.db"
os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB.as_posix()}"
os.environ.pop("DB_HOST", None)
os.environ.setdefault("LOG_LEVEL", "WARNING")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import delete  # noqa: E402

from app.database import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Task  # noqa: E402
from app.prestart import migrate  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _schema():
    migrate()
    yield
    engine.dispose()


@pytest.fixture(autouse=True)
def _clean_tables():
    with SessionLocal() as db:
        db.execute(delete(Task))
        db.commit()
    yield


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def make_task(client):
    def _make(**overrides):
        body = {"title": "Write the Helm chart", "priority": "medium"} | overrides
        response = client.post("/api/tasks", json=body)
        assert response.status_code == 201, response.text
        return response.json()

    return _make
