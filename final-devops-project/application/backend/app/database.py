"""SQLAlchemy engine, session factory and the FastAPI session dependency."""

from collections.abc import Iterator

from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings


class Base(DeclarativeBase):
    pass


def build_engine(url: URL | str) -> Engine:
    url_str = url.render_as_string(hide_password=False) if isinstance(url, URL) else url
    if url_str.startswith("sqlite"):
        # SQLite is only used for local runs and tests; FastAPI may use the
        # connection from a different thread than the one that opened it.
        return create_engine(url_str, connect_args={"check_same_thread": False})
    return create_engine(url_str, pool_pre_ping=True, pool_size=5, max_overflow=5)


engine = build_engine(get_settings().sqlalchemy_url())
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ping(db: Session) -> None:
    """Raise if the database cannot answer a trivial query."""
    db.execute(text("SELECT 1"))
