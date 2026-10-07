"""Flask application factory and HTTP routes."""

import os
from html import escape

from flask import Flask, jsonify, request

from app.converter import CATEGORIES, ConversionError, convert


def app_info() -> dict:
    """Build metadata injected by the Dockerfile build args / k8s env."""
    return {
        "app": "session16-cicd-demo",
        "version": os.getenv("APP_VERSION", "dev"),
        "git_sha": os.getenv("GIT_SHA", "local"),
        "environment": os.getenv("APP_ENV", "local"),
    }


def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def index():
        info = app_info()
        return (
            "<!doctype html><html><head><title>Session 16 CI/CD Demo</title></head>"
            "<body style='font-family:sans-serif;max-width:40rem;margin:2rem auto'>"
            "<h1>Session 16 - CI/CD Demo</h1>"
            "<p>Unit converter API built, tested and deployed by GitHub Actions.</p>"
            "<ul>"
            f"<li>Version: <code>{escape(info['version'])}</code></li>"
            f"<li>Git SHA: <code>{escape(info['git_sha'])}</code></li>"
            f"<li>Environment: <code>{escape(info['environment'])}</code></li>"
            "</ul>"
            "<p>Try <code>/health</code>, <code>/api/units</code> or "
            "<code>/api/convert?category=length&amp;value=5&amp;from=km&amp;to=mi</code></p>"
            "</body></html>"
        )

    @app.get("/health")
    def health():
        return jsonify(status="ok", **app_info())

    @app.get("/api/units")
    def units():
        return jsonify({name: list(names) for name, names in CATEGORIES.items()})

    @app.get("/api/convert")
    def convert_endpoint():
        args = request.args
        missing = [k for k in ("category", "value", "from", "to") if not args.get(k)]
        if missing:
            return jsonify(error=f"missing query parameters: {', '.join(missing)}"), 400
        try:
            value = float(args["value"])
        except ValueError:
            return jsonify(error="value must be a number"), 400
        try:
            result = convert(args["category"], value, args["from"], args["to"])
        except ConversionError as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(
            {
                "category": args["category"].lower(),
                "value": value,
                "from": args["from"].lower(),
                "to": args["to"].lower(),
                "result": result,
            }
        )

    return app


app = create_app()

if __name__ == "__main__":  # pragma: no cover
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
