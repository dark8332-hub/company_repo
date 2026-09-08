"""Alerts extensions: grouping, bulk update, maintenance windows/suppression, timeline, stats, runbooks."""
from datetime import datetime, timedelta, timezone

import provider_store


def _items(*keys, status="unavailable", note="활성 Controller SSH 연결 실패: 연결 거부", nodes=None):
    return {key: {"status": status, "name": key, "note": note, "result": "-", "nodes": nodes or []} for key in keys}


def _sync(provider_id, items, check_id="chk-1"):
    provider_store.sync_check_alerts(provider_id, check_id, items)
    return [alert for alert in provider_store.list_alerts(provider_id=provider_id) if alert["status"] != "resolved"]


def test_groups_controller_failure_and_bulk(auth_client, provider_id):
    _sync(provider_id, _items("pcs", "vip", "rabbitmq"))
    response = auth_client.get("/api/alerts/groups")
    assert response.status_code == 200, response.text
    groups = response.json()["groups"]
    controller = [group for group in groups if group["kind"] == "controller"]
    assert len(controller) == 1 and controller[0]["count"] == 3 and controller[0]["severity"] == "critical"
    assert controller[0]["open"] == 3 and len(controller[0]["alert_ids"]) == 3

    bulk = auth_client.post("/api/alerts/bulk", json={"ids": controller[0]["alert_ids"], "status": "acknowledged", "assignee": "ops"})
    assert bulk.status_code == 200 and bulk.json()["updated"] == 3
    assert all(alert["status"] == "acknowledged" and alert["assignee"] == "ops" for alert in bulk.json()["alerts"])
    missing_note = auth_client.post("/api/alerts/bulk", json={"ids": controller[0]["alert_ids"], "status": "resolved"})
    assert missing_note.status_code == 400
    resolved = auth_client.post("/api/alerts/bulk", json={"ids": controller[0]["alert_ids"], "status": "resolved", "resolution_note": "VIP 복구"})
    assert resolved.status_code == 200 and resolved.json()["summary"]["active"] == 0


def test_groups_by_node_and_service_family(auth_client, provider_id):
    items = {}
    items.update(_items("cpu", "memory", status="warning", note="사용률 90%", nodes=[{"hostname": "compute-1", "status": "warning"}]))
    items.update(_items("nova", "nova_log", status="warning", note="down 1건", nodes=[{"hostname": "controller-1", "status": "warning"}, {"hostname": "controller-2", "status": "warning"}]))
    _sync(provider_id, items)
    groups = auth_client.get("/api/alerts/groups").json()["groups"]
    kinds = {group["kind"]: group for group in groups}
    assert kinds["node"]["count"] == 2 and "compute-1" in kinds["node"]["title"]
    assert kinds["service"]["count"] == 2 and "Nova" in kinds["service"]["title"]


def test_maintenance_window_suppresses_alerts(auth_client, provider_id):
    now = datetime.now(timezone.utc)
    payload = {"title": "compute-1 패치", "provider_id": provider_id, "starts_at": (now - timedelta(minutes=5)).isoformat(),
               "ends_at": (now + timedelta(hours=2)).isoformat(), "nodes": ["compute-1"], "item_keys": [], "note": "커널 패치"}
    created = auth_client.post("/api/maintenance-windows", json=payload)
    assert created.status_code == 201, created.text
    window = created.json()
    assert window["state"] == "active" and window["nodes"] == ["compute-1"]

    items = {}
    items.update(_items("cpu", status="warning", note="사용률 91%", nodes=[{"hostname": "compute-1", "status": "warning"}]))
    items.update(_items("disk", status="warning", note="사용률 85%", nodes=[{"hostname": "controller-1", "status": "warning"}]))
    provider_store.sync_check_alerts(provider_id, "chk-2", items)
    alerts = {alert["source_key"]: alert for alert in provider_store.list_alerts(provider_id=provider_id)}
    assert alerts["inspection:cpu"]["suppressed"] is True and alerts["inspection:disk"]["suppressed"] is False
    summary = auth_client.get("/api/alerts/summary").json()
    assert summary["active"] == 1 and summary["suppressed"] == 1
    assert [alert["source_key"] for alert in auth_client.get("/api/alerts?status=suppressed").json()["alerts"]] == ["inspection:cpu"]
    assert [alert["source_key"] for alert in auth_client.get("/api/alerts?status=open").json()["alerts"]] == ["inspection:disk"]
    overview = auth_client.get(f"/api/providers/{provider_id}/overview").json()
    assert overview["alerts"]["active"] == 1
    fleet = auth_client.get("/api/overview").json()
    assert fleet["totals"]["active_alerts"] == 1

    events = auth_client.get(f"/api/alerts/{alerts['inspection:cpu']['id']}/events").json()["events"]
    assert {event["kind"] for event in events} >= {"detected", "suppressed"}

    deleted = auth_client.delete(f"/api/maintenance-windows/{window['id']}")
    assert deleted.status_code == 200
    assert auth_client.get("/api/alerts/summary").json()["active"] == 2
    assert auth_client.get("/api/maintenance-windows").json()["windows"] == []


def test_maintenance_window_validation(auth_client, provider_id):
    now = datetime.now(timezone.utc)
    bad_order = auth_client.post("/api/maintenance-windows", json={"title": "x", "starts_at": now.isoformat(), "ends_at": (now - timedelta(hours=1)).isoformat()})
    assert bad_order.status_code == 400
    unknown_node = auth_client.post("/api/maintenance-windows", json={"title": "x", "provider_id": provider_id, "starts_at": now.isoformat(), "ends_at": (now + timedelta(hours=1)).isoformat(), "nodes": ["nope"]})
    assert unknown_node.status_code == 400
    bad_item = auth_client.post("/api/maintenance-windows", json={"title": "x", "provider_id": provider_id, "starts_at": now.isoformat(), "ends_at": (now + timedelta(hours=1)).isoformat(), "item_keys": ["nope"]})
    assert bad_item.status_code == 400
    all_providers = auth_client.post("/api/maintenance-windows", json={"title": "전체", "starts_at": (now + timedelta(days=1)).isoformat(), "ends_at": (now + timedelta(days=1, hours=1)).isoformat()})
    assert all_providers.status_code == 201 and all_providers.json()["state"] == "upcoming" and all_providers.json()["provider_id"] is None


def test_timeline_comments_and_stats(auth_client, provider_id):
    _sync(provider_id, _items("nova", status="warning", note="down 1건", nodes=[{"hostname": "controller-1", "status": "warning"}]))
    alert = provider_store.list_alerts(provider_id=provider_id)[0]
    comment = auth_client.post(f"/api/alerts/{alert['id']}/comments", json={"text": "확인 중"})
    assert comment.status_code == 201 and comment.json()["kind"] == "comment" and comment.json()["actor"] == "admin"
    auth_client.put(f"/api/alerts/{alert['id']}", json={"status": "acknowledged", "assignee": "ops", "resolution_note": "", "work_history_id": None})
    provider_store.sync_check_alerts(provider_id, "chk-3", _items("nova", status="warning", note="down 1건", nodes=[{"hostname": "controller-1", "status": "warning"}]))
    auth_client.put(f"/api/alerts/{alert['id']}", json={"status": "resolved", "assignee": "ops", "resolution_note": "재시작", "work_history_id": None})
    kinds = [event["kind"] for event in auth_client.get(f"/api/alerts/{alert['id']}/events").json()["events"]]
    assert kinds[0] == "resolved" and "redetected" in kinds and "acknowledged" in kinds and "assigned" in kinds and "comment" in kinds and kinds[-1] == "detected"
    assert auth_client.post(f"/api/alerts/{alert['id']}/comments", json={"text": ""}).status_code == 422
    assert auth_client.get("/api/alerts/00000000-0000-0000-0000-000000000000/events").status_code == 404

    stats = auth_client.get("/api/alerts/stats?days=30").json()
    assert stats["acknowledged"] == 1 and stats["resolved"] == 1 and stats["mtta_seconds"] is not None and stats["mttr_seconds"] is not None
    assert stats["recurring"] and stats["recurring"][0]["repeats"] == 1 and stats["stale_count"] == 0


def test_runbooks_builtin_and_override(auth_client, provider_id):
    builtin = auth_client.get("/api/runbooks/pcs").json()
    assert builtin["source"] == "builtin" and "pcs status" in builtin["text"] and builtin["editable"] is False
    assert auth_client.get("/api/runbooks/nova_log").json()["source"] == "builtin"
    assert auth_client.get("/api/runbooks/no_such_item").json()["source"] == "generic"
    override = auth_client.put(f"/api/providers/{provider_id}/settings/runbooks", json={"value": {"pcs": "## 사이트 절차\n1. 담당자에게 연락"}})
    assert override.status_code == 200
    site = auth_client.get(f"/api/runbooks/inspection:pcs?provider_id={provider_id}").json()
    assert site["source"] == "provider" and "사이트 절차" in site["text"] and site["editable"] is True
    assert auth_client.get(f"/api/runbooks/vip?provider_id={provider_id}").json()["source"] == "builtin"


def test_active_status_filter_matches_the_summary_card(auth_client, provider_id):
    """The 활성 알림 card sends status=active; it must return exactly what the card counts."""
    _sync(provider_id, _items("pcs", "vip", "rabbitmq"))
    alerts = auth_client.get("/api/alerts").json()["alerts"]
    auth_client.put(f"/api/alerts/{alerts[0]['id']}", json={"status": "acknowledged", "assignee": "ops", "resolution_note": ""})
    auth_client.put(f"/api/alerts/{alerts[1]['id']}", json={"status": "resolved", "assignee": "", "resolution_note": "복구"})

    summary = auth_client.get("/api/alerts/summary").json()
    active = auth_client.get("/api/alerts?status=active").json()["alerts"]
    # acknowledged still counts as active; resolved does not.
    assert len(active) == summary["active"] == 2
    assert {alert["status"] for alert in active} == {"open", "acknowledged"}

    critical = auth_client.get("/api/alerts?status=active&severity=critical").json()["alerts"]
    assert len(critical) == summary["critical"]
    resolved = auth_client.get("/api/alerts?status=resolved").json()["alerts"]
    assert len(resolved) == 1 and resolved[0]["status"] == "resolved"


def test_active_filter_excludes_suppressed_alerts(auth_client, provider_id):
    """Suppressed alerts have their own card, so they must not also appear under 활성 알림."""
    _sync(provider_id, _items("pcs", "vip"))
    start = datetime.now(timezone.utc) - timedelta(minutes=5)
    window = auth_client.post("/api/maintenance-windows", json={
        "title": "정기 점검", "provider_ids": [provider_id], "items": [],
        "starts_at": start.isoformat(), "ends_at": (start + timedelta(hours=2)).isoformat()})
    assert window.status_code == 201, window.text

    summary = auth_client.get("/api/alerts/summary").json()
    active = auth_client.get("/api/alerts?status=active").json()["alerts"]
    suppressed = auth_client.get("/api/alerts?status=suppressed").json()["alerts"]
    assert len(active) == summary["active"]
    assert len(suppressed) == summary["suppressed"] > 0
    assert not [alert for alert in active if alert["suppressed"]]
