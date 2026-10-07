"""/api/tasks CRUD and /api/stats."""

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import metrics
from app.database import get_db
from app.models import Priority, Status, Task
from app.schemas import TaskCreate, TaskRead, TaskStats, TaskUpdate

logger = logging.getLogger("taskflow.tasks")

router = APIRouter(prefix="/api", tags=["tasks"])

DbSession = Annotated[Session, Depends(get_db)]


def _get_or_404(db: Session, task_id: int) -> Task:
    task = db.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


@router.get("/tasks", response_model=list[TaskRead])
def list_tasks(
    db: DbSession,
    status_filter: Annotated[Status | None, Query(alias="status")] = None,
    priority: Priority | None = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
) -> list[Task]:
    stmt = select(Task)
    if status_filter is not None:
        stmt = stmt.where(Task.status == status_filter)
    if priority is not None:
        stmt = stmt.where(Task.priority == priority)
    stmt = stmt.order_by(Task.created_at.desc(), Task.id.desc()).limit(limit)
    return list(db.scalars(stmt))


@router.get("/tasks/{task_id}", response_model=TaskRead)
def get_task(task_id: int, db: DbSession) -> Task:
    return _get_or_404(db, task_id)


@router.post("/tasks", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: DbSession) -> Task:
    task = Task(**payload.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)
    metrics.TASKS_CREATED.labels(priority=task.priority.value).inc()
    logger.info("task created", extra={"task_id": task.id, "priority": task.priority.value})
    return task


@router.put("/tasks/{task_id}", response_model=TaskRead)
def update_task(task_id: int, payload: TaskUpdate, db: DbSession) -> Task:
    task = _get_or_404(db, task_id)
    changes = payload.model_dump(exclude_unset=True)
    if "title" in changes and changes["title"] is None:
        raise HTTPException(status_code=422, detail="title must not be null")
    was_done = task.status == Status.done
    for field, value in changes.items():
        setattr(task, field, value)
    db.commit()
    db.refresh(task)
    if task.status == Status.done and not was_done:
        metrics.TASKS_COMPLETED.inc()
    logger.info("task updated", extra={"task_id": task.id, "fields": sorted(changes)})
    return task


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int, db: DbSession) -> Response:
    task = _get_or_404(db, task_id)
    db.delete(task)
    db.commit()
    metrics.TASKS_DELETED.inc()
    logger.info("task deleted", extra={"task_id": task_id})
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/stats", response_model=TaskStats)
def task_stats(db: DbSession) -> TaskStats:
    rows = db.execute(select(Task.status, func.count()).group_by(Task.status)).all()
    counts = {row[0]: row[1] for row in rows}
    high_open = db.scalar(
        select(func.count())
        .select_from(Task)
        .where(Task.priority == Priority.high, Task.status != Status.done)
    )
    return TaskStats(
        total=sum(counts.values()),
        todo=counts.get(Status.todo, 0),
        in_progress=counts.get(Status.in_progress, 0),
        done=counts.get(Status.done, 0),
        high_priority_open=high_open or 0,
    )
