"""Alembic environment: uses the app's settings and models as the single source of truth."""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import text

from app.config import get_settings
from app.database import build_engine
from app.models import Base

config = context.config
if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata

# Arbitrary constant: "TaskFlow migrations" advisory lock id.
MIGRATION_LOCK_ID = 727274


def run_migrations_offline() -> None:
    """Emit SQL to stdout instead of executing it (alembic upgrade head --sql)."""
    url = get_settings().sqlalchemy_url().render_as_string(hide_password=False)
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = build_engine(get_settings().sqlalchemy_url())
    with engine.connect() as connection:
        is_postgres = connection.dialect.name == "postgresql"
        if is_postgres:
            # Two backend pods starting together must not both run the migration.
            connection.execute(text("SELECT pg_advisory_lock(:id)"), {"id": MIGRATION_LOCK_ID})
            connection.commit()
        try:
            context.configure(
                connection=connection,
                target_metadata=target_metadata,
                render_as_batch=connection.dialect.name == "sqlite",
            )
            with context.begin_transaction():
                context.run_migrations()
            connection.commit()
        finally:
            if is_postgres:
                connection.execute(
                    text("SELECT pg_advisory_unlock(:id)"), {"id": MIGRATION_LOCK_ID}
                )
                connection.commit()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
