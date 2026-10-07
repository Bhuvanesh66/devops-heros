"""Business metrics, exported on /metrics next to the HTTP metrics."""

from prometheus_client import Counter

TASKS_CREATED = Counter(
    "taskflow_tasks_created_total",
    "Tasks created through the API",
    ["priority"],
)
TASKS_COMPLETED = Counter(
    "taskflow_tasks_completed_total",
    "Tasks moved to status done",
)
TASKS_DELETED = Counter(
    "taskflow_tasks_deleted_total",
    "Tasks deleted through the API",
)
