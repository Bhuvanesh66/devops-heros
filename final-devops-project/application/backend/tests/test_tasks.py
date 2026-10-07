"""CRUD tests for /api/tasks and /api/stats."""


def test_create_task_returns_201_with_defaults(client):
    response = client.post("/api/tasks", json={"title": "  Provision the VPC  "})
    assert response.status_code == 201
    task = response.json()
    assert task["id"] > 0
    assert task["title"] == "Provision the VPC"  # surrounding spaces are stripped
    assert task["status"] == "todo"
    assert task["priority"] == "medium"
    assert task["created_at"]


def test_create_task_rejects_blank_title(client):
    response = client.post("/api/tasks", json={"title": "   "})
    assert response.status_code == 422


def test_create_task_rejects_unknown_priority(client):
    response = client.post("/api/tasks", json={"title": "x", "priority": "urgent"})
    assert response.status_code == 422


def test_list_tasks_newest_first_and_filters(client, make_task):
    make_task(title="first", priority="low")
    make_task(title="second", priority="high")
    make_task(title="third", priority="high", status="in_progress")

    all_tasks = client.get("/api/tasks").json()
    assert [t["title"] for t in all_tasks] == ["third", "second", "first"]

    high = client.get("/api/tasks", params={"priority": "high"}).json()
    assert {t["title"] for t in high} == {"second", "third"}

    in_progress = client.get("/api/tasks", params={"status": "in_progress"}).json()
    assert [t["title"] for t in in_progress] == ["third"]


def test_get_task_by_id_and_404(client, make_task):
    task = make_task(title="Write the Dockerfile")
    response = client.get(f"/api/tasks/{task['id']}")
    assert response.status_code == 200
    assert response.json()["title"] == "Write the Dockerfile"

    missing = client.get("/api/tasks/999999")
    assert missing.status_code == 404
    assert missing.json()["detail"] == "Task not found"


def test_update_task_marks_it_done(client, make_task):
    task = make_task(title="Configure the HPA")
    response = client.put(f"/api/tasks/{task['id']}", json={"status": "done"})
    assert response.status_code == 200
    updated = response.json()
    assert updated["status"] == "done"
    assert updated["title"] == "Configure the HPA"  # fields not sent are unchanged


def test_update_task_validation_and_404(client, make_task):
    task = make_task()
    assert client.put(f"/api/tasks/{task['id']}", json={"title": ""}).status_code == 422
    assert client.put(f"/api/tasks/{task['id']}", json={"title": None}).status_code == 422
    assert client.put("/api/tasks/999999", json={"status": "done"}).status_code == 404


def test_delete_task(client, make_task):
    task = make_task(title="Remove me")
    response = client.delete(f"/api/tasks/{task['id']}")
    assert response.status_code == 204
    assert client.get(f"/api/tasks/{task['id']}").status_code == 404
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 404


def test_stats_counts_by_status(client, make_task):
    make_task(title="a", priority="high")
    make_task(title="b", priority="high", status="done")
    make_task(title="c", status="in_progress")

    stats = client.get("/api/stats").json()
    assert stats == {
        "total": 3,
        "todo": 1,
        "in_progress": 1,
        "done": 1,
        "high_priority_open": 1,
    }
