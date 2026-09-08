"""Issue notes: CRUD, status transitions, code snippets, timeline comments, links to alerts / work histories / checks, Markdown export."""
from datetime import datetime, timezone

import provider_store
import server
from conftest import FAKE_NODES, FAKE_PROVIDER


def new_issue(auth_client, **overrides):
    payload = {"title": "nova-compute 가 주기적으로 down", "severity": "high", "category": "incident",
               "tags": ["nova", "#libvirt", "nova"], "body": "## 증상\n- 5분마다 down\n\n```bash\nsystemctl status nova-compute\n```"}
    payload.update(overrides)
    response = auth_client.post("/api/issues", json=payload)
    assert response.status_code == 201, response.text
    return response.json()


def audit_actions() -> list[str]:
    return [item["action"] for item in provider_store.list_audit_logs(limit=100)["items"]]


def seed_provider() -> str:
    new_id = provider_store.save_provider(dict(FAKE_PROVIDER), {"password": "not-a-real-password"})
    provider_store.save_provider_nodes(new_id, [dict(node) for node in FAKE_NODES])
    return new_id


# --- create / read / list ----------------------------------------------------------------------

def test_requires_login(client):
    assert client.get("/api/issues").status_code == 401
    assert client.post("/api/issues", json={"title": "x"}).status_code == 401


def test_create_assigns_sequential_key_and_normalizes_tags(auth_client):
    first = new_issue(auth_client)
    second = new_issue(auth_client, title="두 번째")
    assert first["key"] == "ISS-1" and second["key"] == "ISS-2"
    assert first["tags"] == ["nova", "libvirt"], "duplicates and leading # are dropped"
    assert first["reporter"] == "admin"
    assert first["status"] == "open" and first["resolved_at"] is None
    assert [event["kind"] for event in first["events"]] == ["created"]
    assert "issue.create" in audit_actions()


def test_detail_by_id_or_number(auth_client):
    issue = new_issue(auth_client)
    by_id = auth_client.get(f"/api/issues/{issue['id']}").json()
    by_number = auth_client.get(f"/api/issues/{issue['number']}").json()
    assert by_id["id"] == by_number["id"] == issue["id"]
    assert auth_client.get("/api/issues/does-not-exist").status_code == 404


def test_validation_rejects_unknown_enums(auth_client):
    for field, value in (("status", "closed"), ("severity", "blocker"), ("category", "wishlist")):
        response = auth_client.post("/api/issues", json={"title": "x", field: value})
        assert response.status_code == 422, (field, response.text)
    assert auth_client.post("/api/issues", json={"title": "   "}).status_code == 400
    assert auth_client.post("/api/issues", json={"title": "x", "provider_id": "nope"}).status_code == 400


def test_list_filters_and_search_including_snippet_code(auth_client):
    a = new_issue(auth_client, title="Neutron agent 죽음", severity="critical", category="incident", tags=["neutron"])
    b = new_issue(auth_client, title="Cinder 볼륨 느림", severity="low", category="performance", tags=["cinder"])
    auth_client.post(f"/api/issues/{b['id']}/snippets", json={"language": "bash", "path": "/etc/cinder/cinder.conf", "code": "rbd_store_chunk_size = 4"})
    auth_client.post(f"/api/issues/{a['id']}/transition", json={"status": "resolved", "note": "재시작"})

    ids = lambda response: [item["id"] for item in response.json()["issues"]]  # noqa: E731
    assert ids(auth_client.get("/api/issues?severity=critical")) == [a["id"]]
    assert ids(auth_client.get("/api/issues?category=performance")) == [b["id"]]
    assert ids(auth_client.get("/api/issues?tag=cinder")) == [b["id"]]
    assert ids(auth_client.get("/api/issues?status=resolved")) == [a["id"]]
    assert ids(auth_client.get("/api/issues?q=rbd_store_chunk")) == [b["id"]], "snippet code is searchable"
    assert ids(auth_client.get("/api/issues?q=ISS-1")) == [a["id"]]
    listed = auth_client.get("/api/issues").json()["issues"]
    assert [item["id"] for item in listed] == [b["id"], a["id"]], "resolved issues sort after active ones"
    assert listed[0]["snippet_count"] == 1


def test_summary_counts(auth_client):
    new_issue(auth_client, severity="critical", tags=["nova"])
    resolved = new_issue(auth_client, severity="low", tags=["nova", "ceph"])
    auth_client.post(f"/api/issues/{resolved['id']}/transition", json={"status": "resolved"})
    summary = auth_client.get("/api/issues/summary").json()
    assert summary["total"] == 2 and summary["active"] == 1
    assert summary["by_status"] == {"open": 1, "in_progress": 0, "on_hold": 0, "resolved": 1}
    assert summary["by_severity"]["critical"] == 1 and summary["by_severity"]["low"] == 0, "severity counts only active issues"
    assert summary["tags"][0] == {"tag": "nova", "count": 2}


def test_meta_exposes_labels_and_transitions(auth_client):
    meta = auth_client.get("/api/issues/meta").json()
    assert {item["key"] for item in meta["statuses"]} == set(provider_store.ISSUE_STATUSES)
    assert "bash" in meta["languages"]
    assert set(meta["transitions"]["open"]) == {"in_progress", "on_hold", "resolved"}


# --- update / transition / delete --------------------------------------------------------------

def test_update_records_change_event_and_resolution_time(auth_client):
    issue = new_issue(auth_client)
    payload = {"title": issue["title"], "status": "resolved", "severity": "medium", "category": "incident", "tags": ["nova"],
               "body": issue["body"], "assignee": "홍길동", "resolution": "libvirtd 재시작"}
    updated = auth_client.put(f"/api/issues/{issue['id']}", json=payload).json()
    assert updated["status"] == "resolved" and updated["resolved_at"]
    assert updated["assignee"] == "홍길동"
    latest = updated["events"][0]
    assert latest["kind"] == "status" and "open → resolved" in latest["text"] and "high → medium" in latest["text"] and "홍길동" in latest["text"]
    reopened = auth_client.put(f"/api/issues/{issue['id']}", json={**payload, "status": "open"}).json()
    assert reopened["resolved_at"] is None


def test_transition_enforces_state_machine(auth_client):
    issue = new_issue(auth_client)
    moved = auth_client.post(f"/api/issues/{issue['id']}/transition", json={"status": "in_progress"})
    assert moved.status_code == 200 and moved.json()["status"] == "in_progress"
    resolved = auth_client.post(f"/api/issues/{issue['id']}/transition", json={"status": "resolved", "note": "패치 적용"})
    assert resolved.json()["resolution"] == "패치 적용" and resolved.json()["resolved_at"]
    invalid = auth_client.post(f"/api/issues/{issue['id']}/transition", json={"status": "on_hold"})
    assert invalid.status_code == 409, "resolved → on_hold is not allowed"
    assert auth_client.post(f"/api/issues/{issue['id']}/transition", json={"status": "bogus"}).status_code == 400
    assert "issue.transition" in audit_actions()


def test_delete_removes_snippets_and_events(auth_client):
    issue = new_issue(auth_client)
    auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"language": "python", "code": "print(1)"})
    auth_client.post(f"/api/issues/{issue['id']}/comments", json={"text": "확인 중"})
    assert auth_client.delete(f"/api/issues/{issue['id']}").status_code == 200
    assert auth_client.get(f"/api/issues/{issue['id']}").status_code == 404
    with provider_store._connect() as connection:
        assert connection.execute("SELECT COUNT(*) FROM issue_snippets").fetchone()[0] == 0
        assert connection.execute("SELECT COUNT(*) FROM issue_events").fetchone()[0] == 0
    assert auth_client.delete(f"/api/issues/{issue['id']}").status_code == 404


# --- snippets and comments ---------------------------------------------------------------------

def test_snippet_lifecycle(auth_client):
    issue = new_issue(auth_client)
    created = auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"title": "설정", "path": "/etc/nova/nova.conf", "language": "ini", "code": "[libvirt]\nvirt_type = kvm"})
    assert created.status_code == 201, created.text
    snippet = created.json()
    assert snippet["position"] == 1 and snippet["created_by"] == "admin"
    second = auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"language": "bash", "code": "virsh list"}).json()
    assert second["position"] == 2
    edited = auth_client.put(f"/api/issues/{issue['id']}/snippets/{snippet['id']}", json={"title": "설정", "path": "/etc/nova/nova.conf", "language": "ini", "code": "[libvirt]\nvirt_type = qemu"})
    assert edited.status_code == 200 and "qemu" in edited.json()["code"]
    assert auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"language": "cobol", "code": "x"}).status_code == 422
    assert auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"language": "bash", "code": ""}).status_code == 422
    listed = auth_client.get(f"/api/issues/{issue['id']}/snippets").json()["snippets"]
    assert [item["id"] for item in listed] == [snippet["id"], second["id"]]
    assert auth_client.delete(f"/api/issues/{issue['id']}/snippets/{snippet['id']}").status_code == 200
    assert auth_client.delete(f"/api/issues/{issue['id']}/snippets/{snippet['id']}").status_code == 404
    kinds = [event["kind"] for event in auth_client.get(f"/api/issues/{issue['id']}/events").json()["events"]]
    assert kinds.count("snippet") == 4, "add, add, edit, delete are all on the timeline"
    assert {"issue.snippet.add", "issue.snippet.update", "issue.snippet.delete"} <= set(audit_actions())


def test_comments_append_to_timeline(auth_client):
    issue = new_issue(auth_client)
    response = auth_client.post(f"/api/issues/{issue['id']}/comments", json={"text": "  로그 확인 중  "})
    assert response.status_code == 201 and response.json()["text"] == "로그 확인 중" and response.json()["actor"] == "admin"
    assert auth_client.post(f"/api/issues/{issue['id']}/comments", json={"text": ""}).status_code == 422
    detail = auth_client.get(f"/api/issues/{issue['id']}").json()
    assert detail["comment_count"] == 1 and detail["events"][0]["kind"] == "comment"
    assert "issue.comment" in audit_actions()


# --- links to alerts, work histories and checks ------------------------------------------------

def test_links_validate_and_resolve(auth_client):
    provider_id = seed_provider()
    check_id = provider_store.save_check(provider_id, "warning", {"items": {"nova": {"status": "warning", "result": "-", "note": ""}}, "nodes": [], "node_summary": [], "selected_items": ["nova"], "trigger": "manual"})
    alert_id = provider_store.upsert_monitoring_alert(provider_id, "test:key", "warning", "테스트 알림", "설명", "hcom01")["id"]
    history = auth_client.post("/api/work-histories", json={"title": "HAProxy 변경", "work_type": "change", "status": "planned", "operator": "tester",
                                                             "description": "x", "started_at": datetime.now(timezone.utc).isoformat()}).json()
    assert auth_client.post("/api/issues", json={"title": "x", "alert_id": "nope"}).status_code == 400
    assert auth_client.post("/api/issues", json={"title": "x", "work_history_id": "nope"}).status_code == 400
    assert auth_client.post("/api/issues", json={"title": "x", "check_id": check_id}).status_code == 400, "a check link needs its provider"

    issue = new_issue(auth_client, provider_id=provider_id, alert_id=alert_id, work_history_id=history["id"], check_id=check_id)
    assert issue["provider_name"] == FAKE_PROVIDER["name"]
    assert issue["links"]["alert"]["title"] == "테스트 알림"
    assert issue["links"]["work_history"]["title"] == "HAProxy 변경"
    assert issue["links"]["check"]["id"] == check_id
    assert [item["id"] for item in auth_client.get(f"/api/issues?alert_id={alert_id}").json()["issues"]] == [issue["id"]]
    assert [item["id"] for item in auth_client.get(f"/api/issues?work_history_id={history['id']}").json()["issues"]] == [issue["id"]]

    auth_client.delete(f"/api/work-histories/{history['id']}")
    assert auth_client.get(f"/api/issues/{issue['id']}").json()["work_history_id"] is None, "deleting the work history unlinks it"
    provider_store.delete_provider(provider_id)
    assert auth_client.get(f"/api/issues/{issue['id']}").json()["provider_id"] is None, "deleting the provider keeps the issue"


# --- export ------------------------------------------------------------------------------------

def test_markdown_export(auth_client):
    issue = new_issue(auth_client, tags=["nova"])
    auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"title": "확인 명령", "path": "hcom01", "language": "bash", "code": "systemctl status nova-compute\n"})
    auth_client.post(f"/api/issues/{issue['id']}/comments", json={"text": "코멘트 하나"})
    response = auth_client.get(f"/api/issues/{issue['id']}/export")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/markdown")
    assert "ISS-1.md" in response.headers["content-disposition"]
    text = response.text
    assert text.startswith("# ISS-1 nova-compute 가 주기적으로 down")
    assert "- 태그: #nova" in text
    assert "### 확인 명령 · hcom01" in text and "```bash\nsystemctl status nova-compute\n```" in text
    assert "코멘트 하나" in text
    assert "issue.export" in audit_actions()


def test_export_uses_longer_fence_when_code_contains_backticks(auth_client):
    issue = new_issue(auth_client)
    auth_client.post(f"/api/issues/{issue['id']}/snippets", json={"language": "text", "code": "```\ninner\n```"})
    text = auth_client.get(f"/api/issues/{issue['id']}/export").text
    assert "````text\n```\ninner\n```\n````" in text


def test_menu_settings_accept_issues_key(auth_client):
    assert "issues" in server.MENU_KEYS
