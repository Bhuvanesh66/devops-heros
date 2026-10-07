def test_index_shows_version_and_sha(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_data(as_text=True)
    assert "Session 16 - CI/CD Demo" in body
    assert "1.2.3" in body
    assert "abc1234" in body


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["app"] == "session16-cicd-demo"


def test_units_lists_categories(client):
    data = client.get("/api/units").get_json()
    assert set(data) == {"length", "mass", "temperature"}
    assert "km" in data["length"]


def test_convert_success(client):
    response = client.get("/api/convert?category=length&value=5&from=km&to=m")
    assert response.status_code == 200
    data = response.get_json()
    assert data["result"] == 5000.0
    assert data["from"] == "km"
    assert data["to"] == "m"


def test_convert_missing_params(client):
    response = client.get("/api/convert?category=length")
    assert response.status_code == 400
    assert "missing query parameters" in response.get_json()["error"]


def test_convert_non_numeric_value(client):
    response = client.get("/api/convert?category=length&value=abc&from=km&to=m")
    assert response.status_code == 400
    assert response.get_json()["error"] == "value must be a number"


def test_convert_bad_unit(client):
    response = client.get("/api/convert?category=mass&value=1&from=kg&to=ton")
    assert response.status_code == 400
    assert "unsupported units" in response.get_json()["error"]


def test_unknown_route_is_404(client):
    assert client.get("/does-not-exist").status_code == 404
