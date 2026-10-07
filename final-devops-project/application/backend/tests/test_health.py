"""Probe endpoints, metrics and the migration."""

from sqlalchemy import inspect
from sqlalchemy.exc import OperationalError

from app.database import engine, get_db
from app.main import app


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_ready_checks_the_database(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready", "database": "ok"}


def test_ready_returns_503_when_database_is_down(client):
    class BrokenSession:
        def execute(self, *args, **kwargs):
            raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    app.dependency_overrides[get_db] = lambda: BrokenSession()
    try:
        response = client.get("/ready")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 503
    assert response.json()["database"] == "unreachable"


def test_metrics_exposes_prometheus_format(client, make_task):
    make_task(title="count me")
    client.get("/api/tasks")
    response = client.get("/metrics")
    assert response.status_code == 200
    body = response.text
    assert "http_requests_total" in body
    assert 'handler="/api/tasks"' in body
    assert "taskflow_tasks_created_total" in body


def test_alembic_migration_created_tasks_table():
    inspector = inspect(engine)
    assert "tasks" in inspector.get_table_names()
    assert "alembic_version" in inspector.get_table_names()
    columns = {c["name"] for c in inspector.get_columns("tasks")}
    assert {"id", "title", "description", "priority", "status", "due_date"} <= columns
