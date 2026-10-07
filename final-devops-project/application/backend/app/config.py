"""Runtime configuration, read only from environment variables (12-factor).

The database location can be given in two ways:

1. DATABASE_URL - a complete SQLAlchemy URL, e.g.
   postgresql+psycopg://taskflow:<password>@postgres:5432/taskflow
   (used by docker compose, the CI smoke test and the tests).
2. DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWORD - the pieces, used in
   Kubernetes where the non-secret parts come from a ConfigMap and the
   credentials come from a Secret. The URL is assembled here, so a password
   with special characters never has to be URL-encoded by hand.

If neither is set, a local SQLite file is used so `uvicorn app.main:app`
works on a laptop without PostgreSQL.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "TaskFlow API"
    app_env: str = "development"
    log_level: str = "INFO"

    database_url: str | None = None
    db_host: str | None = None
    db_port: int = 5432
    db_name: str = "taskflow"
    db_user: str | None = None
    db_password: str | None = None

    # Comma-separated list. Empty means "same origin only" (the normal case,
    # because nginx serves the UI and proxies /api on the same host).
    cors_origins: str = ""

    def sqlalchemy_url(self) -> URL:
        if self.database_url:
            return make_url(self.database_url)
        if self.db_host:
            return URL.create(
                drivername="postgresql+psycopg",
                username=self.db_user,
                password=self.db_password,
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
            )
        return make_url("sqlite:///./taskflow.db")

    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
