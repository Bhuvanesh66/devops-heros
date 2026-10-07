"""ORM models. The table itself is created by the Alembic migration, not by the app."""

import enum
from datetime import UTC, date, datetime

from sqlalchemy import Date, DateTime, Enum, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


class Priority(enum.StrEnum):
    low = "low"
    medium = "medium"
    high = "high"


class Status(enum.StrEnum):
    todo = "todo"
    in_progress = "in_progress"
    done = "done"


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[Priority] = mapped_column(
        Enum(Priority, name="task_priority", native_enum=False, length=10),
        nullable=False,
        default=Priority.medium,
    )
    status: Mapped[Status] = mapped_column(
        Enum(Status, name="task_status", native_enum=False, length=20),
        nullable=False,
        default=Status.todo,
        index=True,
    )
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )
