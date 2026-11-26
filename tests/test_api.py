from app.main import create_app


def client():
    return create_app().test_client()


def test_health():
    res = client().get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "UP"


def test_add_and_list_task():
    c = client()
    res = c.post("/api/tasks", json={"title": "Write report"})
    assert res.status_code == 201
    assert c.get("/api/tasks").get_json()[0]["title"] == "Write report"


def test_add_task_without_title_fails():
    assert client().post("/api/tasks", json={}).status_code == 400
