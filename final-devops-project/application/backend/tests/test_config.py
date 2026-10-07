"""How the database URL is resolved from the environment."""

from app.config import Settings


def test_database_url_wins_when_set():
    settings = Settings(database_url="sqlite:///./x.db", db_host="ignored")
    assert settings.sqlalchemy_url().render_as_string() == "sqlite:///./x.db"


def test_url_is_built_from_parts_with_password_escaped():
    # Kubernetes style: host/port/name from the ConfigMap, user/password from the Secret.
    settings = Settings(
        database_url=None,
        db_host="taskflow-postgres",
        db_port=5432,
        db_name="taskflow",
        db_user="taskflow",
        db_password="p@ss:w/rd",
    )
    url = settings.sqlalchemy_url()
    assert url.drivername == "postgresql+psycopg"
    assert url.host == "taskflow-postgres"
    assert url.password == "p@ss:w/rd"
    # special characters are percent-encoded in the rendered URL
    assert "p%40ss%3Aw%2Frd@taskflow-postgres:5432/taskflow" in url.render_as_string(
        hide_password=False
    )


def test_sqlite_fallback_without_any_database_settings():
    settings = Settings(database_url=None, db_host=None)
    assert settings.sqlalchemy_url().drivername == "sqlite"


def test_cors_origins_are_split_and_trimmed():
    settings = Settings(cors_origins=" http://a.test , ,http://b.test")
    assert settings.cors_origin_list() == ["http://a.test", "http://b.test"]
