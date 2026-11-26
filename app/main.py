"""Task API - a tiny REST API used as the subject of the CI/CD pipeline."""
import os

from flask import Flask, jsonify, request

APP_VERSION = os.getenv("APP_VERSION", "dev")


def create_app():
    app = Flask(__name__)
    tasks = []

    @app.get("/health")
    def health():
        return jsonify(status="UP", version=APP_VERSION)

    @app.get("/api/tasks")
    def list_tasks():
        return jsonify(tasks)

    @app.post("/api/tasks")
    def add_task():
        data = request.get_json(silent=True) or {}
        title = str(data.get("title", "")).strip()
        if not title:
            return jsonify(error="title is required"), 400
        task = {"id": len(tasks) + 1, "title": title, "done": False}
        tasks.append(task)
        return jsonify(task), 201

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
