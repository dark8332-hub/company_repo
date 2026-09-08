"""Work history extensions: approval flow, operator auto-fill, before/after checks, attachments, monthly CSV."""
import io
from datetime import datetime, timedelta, timezone

import provider_store
import server


def new_history(auth_client, **overrides):
    payload = {
        "title": "HAProxy 설정 변경", "work_type": "change", "status": "planned", "operator": "tester",
        "description": "## 목적\n- 타임아웃 조정", "started_at": datetime.now(timezone.utc).isoformat(),
    }
    payload.update(overrides)
    response = auth_client.post("/api/work-histories", json=payload)
    assert response.status_code == 201, response.text
    return response.json()


def stored_check(provider_id: str, statuses: dict) -> str:
    result = {"items": {key: {"status": status, "result": "-", "note": ""} for key, status in statuses.items()}, "nodes": [], "node_summary": [],
              "selected_items": list(statuses), "trigger": "manual"}
    overall = "healthy" if all(value == "healthy" for value in statuses.values()) else "warning"
    return provider_store.save_check(provider_id, overall, result)


def audit_actions() -> list[str]:
    return [item["action"] for item in provider_store.list_audit_logs(limit=100)["items"]]


# --- W1: operator auto-fill and approval flow ---------------------------------------------------

def test_blank_operator_defaults_to_login_user(auth_client):
    history = new_history(auth_client, operator="")
    assert history["operator"] == "admin"


def test_blank_operator_keeps_explicit_value(auth_client):
    assert new_history(auth_client, operator="  홍길동 ")["operator"] == "홍길동"


def test_approved_status_is_accepted(auth_client):
    assert new_history(auth_client, status="approved")["status"] == "approved"


def test_transition_flow_records_approver_and_completion(auth_client):
    history = new_history(auth_client)
    hid = history["id"]
    approved = auth_client.post(f"/api/work-histories/{hid}/transition", json={"status": "approved"})
    assert approved.status_code == 200, approved.text
    assert approved.json()["status"] == "approved"
    assert approved.json()["approved_by"] == "admin"
    assert approved.json()["approved_at"]
    started = auth_client.post(f"/api/work-histories/{hid}/transition", json={"status": "in_progress"}).json()
    assert started["status"] == "in_progress" and started["completed_at"] is None
    done = auth_client.post(f"/api/work-histories/{hid}/transition", json={"status": "completed"}).json()
    assert done["status"] == "completed" and done["completed_at"]
    assert done["approved_by"] == "admin"
    assert audit_actions().count("work_history.transition") == 3


def test_invalid_transition_is_rejected(auth_client):
    hid = new_history(auth_client)["id"]
    response = auth_client.post(f"/api/work-histories/{hid}/transition", json={"status": "completed"})
    assert response.status_code == 409
    assert auth_client.post(f"/api/work-histories/{hid}/transition", json={"status": "bogus"}).status_code == 400
    assert auth_client.post("/api/work-histories/missing/transition", json={"status": "approved"}).status_code == 404


def test_transition_requires_login(client):
    assert client.post("/api/work-histories/x/transition", json={"status": "approved"}).status_code == 401


# --- W2: before/after checks --------------------------------------------------------------------

def test_check_run_requires_provider_and_valid_phase(auth_client, provider_id):
    common = new_history(auth_client)["id"]
    assert auth_client.post(f"/api/work-histories/{common}/checks/before", json={}).status_code == 400
    linked = new_history(auth_client, provider_id=provider_id)["id"]
    assert auth_client.post(f"/api/work-histories/{linked}/checks/sideways", json={}).status_code == 400
    assert auth_client.post("/api/work-histories/missing/checks/before", json={}).status_code == 404


def test_check_run_refused_while_provider_busy(auth_client, provider_id):
    hid = new_history(auth_client, provider_id=provider_id)["id"]
    server.CHECK_PROGRESS[provider_id] = {"running": True}
    try:
        assert auth_client.post(f"/api/work-histories/{hid}/checks/after", json={}).status_code == 409
    finally:
        server.CHECK_PROGRESS.clear()


def test_link_checks_validates_ownership_and_comparison_builds_diff(auth_client, provider_id):
    hid = new_history(auth_client, provider_id=provider_id)["id"]
    empty = auth_client.get(f"/api/work-histories/{hid}/comparison").json()
    assert empty["before"] is None and empty["after"] is None and empty["diff"] is None
    assert auth_client.put(f"/api/work-histories/{hid}/checks", json={"before_check_id": "nope"}).status_code == 400
    before = stored_check(provider_id, {"cpu": "healthy", "memory": "warning", "disk": "healthy"})
    after = stored_check(provider_id, {"cpu": "healthy", "memory": "healthy", "disk": "unavailable"})
    linked = auth_client.put(f"/api/work-histories/{hid}/checks", json={"before_check_id": before, "after_check_id": after})
    assert linked.status_code == 200, linked.text
    assert linked.json()["before_check_id"] == before and linked.json()["after_check_id"] == after
    comparison = auth_client.get(f"/api/work-histories/{hid}/comparison").json()
    assert comparison["before"]["id"] == before and comparison["after"]["id"] == after
    counts = comparison["diff"]["counts"]
    assert counts["new_issue"] == 1 and counts["resolved"] == 1
    changes = {item["key"]: item["change"] for item in comparison["diff"]["items"]}
    assert changes == {"memory": "resolved", "disk": "new_issue"}
    assert "work_history.check" in audit_actions()


def test_link_checks_rejects_other_provider(auth_client, provider_id):
    other = provider_store.save_provider({**provider_store.get_provider(provider_id), "name": "Other", "fingerprint": "x", "available_tools": []}, {"password": "x"})
    foreign = stored_check(other, {"cpu": "healthy"})
    hid = new_history(auth_client, provider_id=provider_id)["id"]
    assert auth_client.put(f"/api/work-histories/{hid}/checks", json={"after_check_id": foreign}).status_code == 400


# --- W3: attachments ----------------------------------------------------------------------------

def upload(auth_client, hid, name="memo.txt", content=b"hello", content_type="text/plain"):
    return auth_client.post(f"/api/work-histories/{hid}/attachments", files={"file": (name, io.BytesIO(content), content_type)})


def test_attachment_lifecycle(auth_client):
    hid = new_history(auth_client)["id"]
    created = upload(auth_client, hid, "결과 로그.txt", b"line1\nline2")
    assert created.status_code == 201, created.text
    attachment = created.json()
    assert attachment["filename"] == "결과 로그.txt" and attachment["size"] == 11 and attachment["uploaded_by"] == "admin"
    listing = auth_client.get(f"/api/work-histories/{hid}/attachments").json()
    assert [item["id"] for item in listing["attachments"]] == [attachment["id"]]
    assert listing["max_files"] == 10
    download = auth_client.get(f"/api/work-histories/{hid}/attachments/{attachment['id']}")
    assert download.status_code == 200 and download.content == b"line1\nline2"
    assert "attachment" in download.headers["content-disposition"]
    stored = provider_store.attachment_dir(hid)
    assert any(stored.iterdir())
    assert auth_client.delete(f"/api/work-histories/{hid}/attachments/{attachment['id']}").status_code == 200
    assert auth_client.get(f"/api/work-histories/{hid}/attachments/{attachment['id']}").status_code == 404
    assert not any(stored.iterdir())
    actions = audit_actions()
    assert "work_history.attachment.add" in actions and "work_history.attachment.delete" in actions


def test_attachment_limits(auth_client):
    hid = new_history(auth_client)["id"]
    assert upload(auth_client, hid, "empty.bin", b"").status_code == 400
    assert upload(auth_client, hid, "big.bin", b"x" * (10 * 1024 * 1024 + 1)).status_code == 413
    for index in range(10):
        assert upload(auth_client, hid, f"f{index}.txt", b"x").status_code == 201
    assert upload(auth_client, hid, "f10.txt", b"x").status_code == 400
    assert upload(auth_client, "missing", "f.txt", b"x").status_code == 404


def test_deleting_history_removes_attachment_files(auth_client):
    hid = new_history(auth_client)["id"]
    assert upload(auth_client, hid).status_code == 201
    folder = provider_store.attachment_dir(hid)
    assert folder.is_dir()
    assert auth_client.delete(f"/api/work-histories/{hid}").status_code == 200
    assert not folder.exists()
    assert provider_store.list_work_history_attachments(hid) == []


# --- W4: monthly CSV report ---------------------------------------------------------------------

def test_monthly_csv_export(auth_client, provider_id):
    now = datetime.now(timezone.utc).replace(day=15)
    month = now.strftime("%Y-%m")
    new_history(auth_client, title="이번 달 작업", started_at=now.isoformat(), provider_id=provider_id)
    new_history(auth_client, title="지난 달 작업", started_at=(now - timedelta(days=45)).isoformat())
    new_history(auth_client, title="공통 작업", started_at=now.isoformat())
    response = auth_client.get(f"/api/work-history-reports/monthly.csv?month={month}")
    assert response.status_code == 200, response.text
    assert response.headers["content-type"].startswith("text/csv")
    assert response.content.startswith("﻿".encode("utf-8"))
    text = response.content.decode("utf-8-sig")
    lines = [line for line in text.splitlines() if line]
    assert lines[0].startswith("시작 시각,완료 시각,공급자,제목")
    assert "이번 달 작업" in text and "공통 작업" in text and "지난 달 작업" not in text
    filtered = auth_client.get(f"/api/work-history-reports/monthly.csv?month={month}&provider_id={provider_id}").content.decode("utf-8-sig")
    assert "이번 달 작업" in filtered and "공통 작업" not in filtered
    assert auth_client.get("/api/work-history-reports/monthly.csv?month=2026-13").status_code == 422
    assert "work_history.export" in audit_actions()


def test_csv_export_requires_login(client):
    assert client.get("/api/work-history-reports/monthly.csv?month=2026-09").status_code == 401
