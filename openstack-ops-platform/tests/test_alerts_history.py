"""Work histories and alerts on an empty database."""
import uuid

import pytest

MISSING = str(uuid.uuid4())

VALID_HISTORY = {
    "title": "Restart nova-compute",
    "work_type": "restart",
    "status": "completed",
    "operator": "  ops-user  ",
    "target": "compute-1",
    "ticket": "OPS-1",
    "description": "  Restarted after memory leak  ",
    "started_at": "2026-09-01T10:00:00+09:00",
    "completed_at": "2026-09-01T10:30:00+09:00",
}


def test_work_histories_empty(auth_client):
    assert auth_client.get("/api/work-histories").json() == {"histories": []}


def test_work_history_crud(auth_client):
    created = auth_client.post("/api/work-histories", json=VALID_HISTORY)
    assert created.status_code == 201, created.text
    history = created.json()
    history_id = history["id"]
    assert history["title"] == "Restart nova-compute"
    assert history["operator"] == "ops-user"          # stripped
    assert history["description"] == "Restarted after memory leak"
    assert history["provider_id"] is None and history["provider_name"] is None
    assert history["created_at"] and history["updated_at"]

    listed = auth_client.get("/api/work-histories").json()["histories"]
    assert [item["id"] for item in listed] == [history_id]

    detail = auth_client.get(f"/api/work-histories/{history_id}")
    assert detail.status_code == 200 and detail.json()["id"] == history_id

    updated = auth_client.put(f"/api/work-histories/{history_id}", json={**VALID_HISTORY, "status": "failed", "result": "rolled back"})
    assert updated.status_code == 200, updated.text
    assert updated.json()["status"] == "failed" and updated.json()["result"] == "rolled back"

    deleted = auth_client.delete(f"/api/work-histories/{history_id}")
    assert deleted.status_code == 200 and deleted.json() == {"status": "deleted"}
    assert auth_client.get(f"/api/work-histories/{history_id}").status_code == 404
    assert auth_client.delete(f"/api/work-histories/{history_id}").status_code == 404
    assert auth_client.put(f"/api/work-histories/{history_id}", json=VALID_HISTORY).status_code == 404


def test_work_history_filters(auth_client):
    auth_client.post("/api/work-histories", json=VALID_HISTORY)
    auth_client.post("/api/work-histories", json={**VALID_HISTORY, "title": "Patch day", "work_type": "maintenance", "status": "planned", "completed_at": None})
    assert len(auth_client.get("/api/work-histories", params={"work_type": "maintenance"}).json()["histories"]) == 1
    assert len(auth_client.get("/api/work-histories", params={"status": "completed"}).json()["histories"]) == 1
    assert len(auth_client.get("/api/work-histories", params={"q": "Patch"}).json()["histories"]) == 1
    assert auth_client.get("/api/work-histories", params={"q": "x" * 201}).status_code == 422


def test_work_history_completed_before_started(auth_client):
    response = auth_client.post("/api/work-histories", json={**VALID_HISTORY, "completed_at": "2026-09-01T09:00:00+09:00"})
    assert response.status_code == 422, response.text


@pytest.mark.parametrize("field,value", [("work_type", "vacation"), ("status", "done"), ("title", ""), ("description", ""), ("started_at", "not-a-date")])
def test_work_history_invalid_fields(auth_client, field, value):
    response = auth_client.post("/api/work-histories", json={**VALID_HISTORY, field: value})
    assert response.status_code == 422, response.text


def test_work_history_unknown_provider(auth_client):
    response = auth_client.post("/api/work-histories", json={**VALID_HISTORY, "provider_id": MISSING})
    assert response.status_code == 400


def test_work_history_linked_to_provider(auth_client, provider_id):
    created = auth_client.post("/api/work-histories", json={**VALID_HISTORY, "provider_id": provider_id})
    assert created.status_code == 201
    assert created.json()["provider_name"] == "Test Provider"
    overview = auth_client.get(f"/api/providers/{provider_id}/overview").json()
    assert [item["id"] for item in overview["work_histories"]] == [created.json()["id"]]
    assert len(auth_client.get("/api/work-histories", params={"provider_id": provider_id}).json()["histories"]) == 1
    # Deleting the provider keeps the history but detaches it.
    auth_client.delete(f"/api/providers/{provider_id}")
    detail = auth_client.get(f"/api/work-histories/{created.json()['id']}").json()
    assert detail["provider_id"] is None


def test_alerts_empty(auth_client):
    body = auth_client.get("/api/alerts").json()
    assert body["alerts"] == []
    assert body["summary"] == {"active": 0, "critical": 0, "suppressed": 0, "groups": []}


def test_alert_summary_empty(auth_client):
    assert auth_client.get("/api/alerts/summary").json() == {"active": 0, "critical": 0, "suppressed": 0, "groups": []}


def test_alert_filters_on_empty(auth_client):
    assert auth_client.get("/api/alerts", params={"status": "open", "severity": "critical", "q": "x"}).json()["alerts"] == []
    assert auth_client.get("/api/alerts", params={"q": "x" * 201}).status_code == 422


def test_alert_unknown_404(auth_client):
    assert auth_client.get(f"/api/alerts/{MISSING}").status_code == 404
    response = auth_client.put(f"/api/alerts/{MISSING}", json={"status": "acknowledged"})
    assert response.status_code == 404


def test_alert_update_validation(auth_client):
    assert auth_client.put(f"/api/alerts/{MISSING}", json={"status": "bogus"}).status_code == 422
    # resolved requires a resolution note (validated before the lookup)
    assert auth_client.put(f"/api/alerts/{MISSING}", json={"status": "resolved"}).status_code == 422
    # unknown work history linked -> 400 (checked before the alert lookup)
    response = auth_client.put(f"/api/alerts/{MISSING}", json={"status": "acknowledged", "work_history_id": MISSING})
    assert response.status_code == 400


def test_alerts_require_login(client):
    assert client.get("/api/alerts").status_code == 401
    assert client.get("/api/work-histories").status_code == 401
