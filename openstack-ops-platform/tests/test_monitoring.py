"""Monitoring extensions: collector settings, threshold rules → alerts, node detail, OpenStack layer, Alertmanager, PromQL proxy.

Prometheus is never contacted: `resolve_prometheus` / `prom_instant` / `prom_range` are monkeypatched on the server module,
which is how the route code looks them up (module globals), so the canned results flow through the real evaluation logic.
"""
from datetime import datetime, timedelta, timezone

import pytest

import provider_store
import server

MISSING = "00000000-0000-4000-8000-000000000000"


def _vector(rows):
    """Canned Prometheus instant-vector result: rows of (labels, value)."""
    return [{"metric": labels, "value": [1_700_000_000, str(value)]} for labels, value in rows]


@pytest.fixture
def fake_prometheus(monkeypatch):
    """Route every Prometheus access to canned answers keyed by a substring of the query."""
    state = {"answers": {}, "base": "http://prom.test:9090", "queries": []}

    async def resolve(client, provider, nodes):
        return state["base"]

    async def instant(client, base_url, query):
        state["queries"].append(query)
        for needle, rows in state["answers"].items():
            if needle in query:
                return _vector(rows)
        return []

    async def ranged(client, base_url, query, seconds, step, end=None):
        now = 1_700_000_000
        return [{"metric": {}, "values": [[now - seconds + index * step, "1.5"] for index in range(0, seconds // step + 1)]}]

    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    monkeypatch.setattr(server, "prom_instant", instant)
    monkeypatch.setattr(server, "prom_range", ranged)
    return state


# --- collector settings ---------------------------------------------------------------------------

def test_monitoring_settings_defaults(auth_client, provider_id):
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/settings")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["prometheus_url"] == "" and body["auth_type"] == "none" and body["verify_tls"] is True
    assert body["secret_configured"] is False and body["source"] == "default"
    assert "secret" not in body and "secret_encrypted" not in body


def test_monitoring_settings_round_trip_encrypts_secret(auth_client, provider_id):
    payload = {"prometheus_url": "https://prom.example.com:9090/", "auth_type": "basic", "username": "viewer", "secret": "s3cret!",
               "verify_tls": False, "grafana_url": "http://grafana.example.com:3000", "alertmanager_url": "http://am.example.com:9093"}
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/settings", json=payload)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["prometheus_url"] == "https://prom.example.com:9090"  # trailing slash stripped
    assert body["secret_configured"] is True and body["source"] == "stored" and body["verify_tls"] is False
    assert "secret" not in body
    stored = provider_store.get_setting(server.provider_setting_key(provider_id, "monitoring"))
    assert stored["secret_encrypted"] != "s3cret!" and provider_store.decrypt_secret(stored["secret_encrypted"]) == "s3cret!"
    # secret=None keeps the stored secret, a new URL is applied
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/settings", json={**payload, "secret": None, "prometheus_url": "http://10.0.0.1:9090"})
    assert response.status_code == 200 and response.json()["secret_configured"] is True and response.json()["prometheus_url"] == "http://10.0.0.1:9090"
    # switching to no auth drops the secret and username
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/settings", json={**payload, "auth_type": "none"})
    assert response.status_code == 200 and response.json()["secret_configured"] is False and response.json()["username"] == ""
    # the audit trail names the change
    logs = auth_client.get("/api/audit-logs", params={"action": "monitoring.settings.update"}).json()
    assert logs["total"] == 3 and logs["items"][0]["target_id"] == provider_id


@pytest.mark.parametrize("payload, message", [
    ({"prometheus_url": "ftp://prom:9090"}, "http://"),
    ({"auth_type": "digest"}, "인증 방식"),
    ({"auth_type": "basic", "username": "", "secret": "x"}, "사용자명"),
    ({"auth_type": "bearer"}, "토큰"),
    ({"grafana_url": "not a url"}, "Grafana"),
])
def test_monitoring_settings_validation(auth_client, provider_id, payload, message):
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/settings", json=payload)
    assert response.status_code == 400, response.text
    assert message in response.json()["detail"]


def test_generic_provider_setting_rejects_monitoring_secret(auth_client, provider_id):
    response = auth_client.put(f"/api/providers/{provider_id}/settings/monitoring", json={"value": {"prometheus_url": "http://p:9090", "secret": "leak"}})
    assert response.status_code == 400
    assert "monitoring/settings" in response.json()["detail"]


def test_monitoring_settings_unknown_provider(auth_client):
    assert auth_client.get(f"/api/providers/{MISSING}/monitoring/settings").status_code == 404
    assert auth_client.put(f"/api/providers/{MISSING}/monitoring/settings", json={}).status_code == 404


def test_monitoring_connection_test_without_prometheus(auth_client, provider_id, monkeypatch):
    async def resolve(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    response = auth_client.post(f"/api/providers/{provider_id}/monitoring/test")
    assert response.status_code == 200
    assert response.json()["status"] == "unavailable" and "9090" in response.json()["error"]


def test_monitoring_connection_test_connected(auth_client, provider_id, fake_prometheus):
    fake_prometheus["answers"] = {"up": [({"job": "node_exporter", "instance": "10.0.0.1:9100"}, 1), ({"job": "haproxy", "instance": "10.0.0.1:9101"}, 0)]}
    response = auth_client.post(f"/api/providers/{provider_id}/monitoring/test")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "connected" and body["source"] == "http://prom.test:9090"
    assert body["targets_total"] == 2 and body["targets_up"] == 1 and body["latency_ms"] is not None


def test_provider_monitoring_uses_configured_client(auth_client, provider_id, fake_prometheus):
    fake_prometheus["answers"] = {"up": [({"job": "node_exporter", "instance": "10.0.0.1:9100", "nodename": "controller-1"}, 1)],
                                  "node_load1": [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 0.5)]}
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring", params={"range": "1h"})
    assert response.status_code == 200, response.text
    prom = response.json()["prometheus"]
    assert prom["status"] == "connected" and prom["source"] == "http://prom.test:9090"
    assert prom["targets_total"] == 1


# --- threshold rules ------------------------------------------------------------------------------

def test_monitoring_rules_default_and_update(auth_client, provider_id):
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/rules")
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "default" and body["value"]["cpu"] == {"warning": 85, "critical": 95} and body["value"]["sustained_minutes"] == 5
    update = {"enabled": True, "sustained_minutes": 10, "cpu": {"warning": 70, "critical": 90}, "memory": {"warning": 80, "critical": 95}, "disk": None,
              "load_per_core": {"warning": 1.5, "critical": 3}, "node_down": True, "target_down": False}
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/rules", json={"value": update})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["source"] == "stored" and body["value"]["cpu"] == {"warning": 70.0, "critical": 90.0} and body["value"]["disk"] is None
    assert body["value"]["target_down"] is False and body["value"]["sustained_minutes"] == 10
    assert server.alert_rules(provider_id)["load_per_core"] == {"warning": 1.5, "critical": 3.0}
    response = auth_client.delete(f"/api/providers/{provider_id}/monitoring/rules")
    assert response.status_code == 200 and response.json()["source"] == "default"


@pytest.mark.parametrize("value, message", [
    ({"cpu": {"warning": 90, "critical": 80}}, "위험 임계치"),
    ({"memory": {"warning": 0, "critical": 50}}, "범위"),
    ({"sustained_minutes": 0}, "지속 시간"),
    ({"disk": {"warning": "high"}}, "숫자"),
])
def test_monitoring_rules_validation(auth_client, provider_id, value, message):
    response = auth_client.put(f"/api/providers/{provider_id}/monitoring/rules", json={"value": value})
    assert response.status_code == 400, response.text
    assert message in response.json()["detail"]


def test_evaluator_creates_updates_and_resolves_alerts(auth_client, provider_id, fake_prometheus):
    def breached():
        return {
            'avg_over_time((100 - ': [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 96.4), ({"instance": "10.0.0.2:9100", "nodename": "controller-2"}, 40)],
            "MemAvailable": [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 88.0)],
            "node_filesystem_avail_bytes": [],
            "node_load1": [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 0.4)],
            "up": [({"job": "node_exporter", "instance": "10.0.0.1:9100", "nodename": "controller-1"}, 1),
                   ({"job": "node_exporter", "instance": "10.0.0.21:9100", "nodename": "compute-1"}, 0),
                   ({"job": "haproxy-exporter", "instance": "10.0.0.10:9101"}, 0)],
        }
    fake_prometheus["answers"] = breached()
    response = auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate")
    assert response.status_code == 200, response.text
    summary = response.json()
    assert summary["status"] == "ok" and summary["active"] == 4 and summary["created"] == 4 and summary["resolved"] == 0
    alerts = auth_client.get("/api/alerts", params={"provider_id": provider_id}).json()["alerts"]
    by_key = {alert["source_key"]: alert for alert in alerts}
    assert by_key["monitor:cpu:controller-1"]["severity"] == "critical" and by_key["monitor:cpu:controller-1"]["category"] == "monitoring"
    assert by_key["monitor:memory:controller-1"]["severity"] == "warning" and "88.0%" in by_key["monitor:memory:controller-1"]["title"]
    assert by_key["monitor:node_down:compute-1"]["severity"] == "critical" and by_key["monitor:node_down:compute-1"]["target"] == "compute-1"
    assert by_key["monitor:target_down:haproxy-exporter:10.0.0.10:9101"]["severity"] == "warning"
    assert all(alert["status"] == "open" for alert in alerts)
    # same breach again: no duplicates, severity can change in place
    fake_prometheus["answers"]['avg_over_time((100 - '] = [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 87.0)]
    summary = auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate").json()
    assert summary["created"] == 0 and summary["active"] == 4
    alerts = auth_client.get("/api/alerts", params={"provider_id": provider_id}).json()["alerts"]
    assert len(alerts) == 4
    cpu = next(alert for alert in alerts if alert["source_key"] == "monitor:cpu:controller-1")
    assert cpu["severity"] == "warning"
    # everything back to normal: monitoring alerts resolve with the return note, inspection alerts untouched
    fake_prometheus["answers"] = {"up": [({"job": "node_exporter", "instance": "10.0.0.1:9100", "nodename": "controller-1"}, 1)]}
    summary = auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate").json()
    assert summary["active"] == 0 and summary["resolved"] == 4
    resolved = auth_client.get("/api/alerts", params={"provider_id": provider_id, "status": "resolved"}).json()["alerts"]
    assert len(resolved) == 4 and all(alert["resolution_note"] == "임계치 이하로 복귀" for alert in resolved)
    events = provider_store.list_alert_events(cpu["id"])
    assert [event["kind"] for event in events][:1] == ["resolved"] and any(event["kind"] == "severity" for event in events)
    facets = auth_client.get("/api/audit-logs", params={"action": "monitoring.evaluate"}).json()
    assert facets["total"] == 3


def test_evaluator_respects_maintenance_windows(auth_client, provider_id, fake_prometheus):
    now = datetime.now(timezone.utc)
    provider_store.save_maintenance_window({"provider_id": provider_id, "title": "controller-1 patching", "starts_at": (now - timedelta(minutes=5)).isoformat(),
                                            "ends_at": (now + timedelta(hours=2)).isoformat(), "nodes": ["controller-1"], "item_keys": []}, "tester")
    fake_prometheus["answers"] = {'avg_over_time((100 - ': [({"instance": "10.0.0.1:9100", "nodename": "controller-1"}, 99), ({"instance": "10.0.0.2:9100", "nodename": "controller-2"}, 99)],
                                  "up": [({"job": "node_exporter", "instance": "10.0.0.1:9100", "nodename": "controller-1"}, 1)]}
    summary = auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate").json()
    assert summary["active"] == 2 and summary["suppressed"] == 1
    alerts = {alert["source_key"]: alert for alert in provider_store.list_alerts(provider_id=provider_id)}
    assert alerts["monitor:cpu:controller-1"]["suppressed_until"] and not alerts["monitor:cpu:controller-2"]["suppressed_until"]


def test_evaluator_skips_when_disabled_or_no_prometheus(auth_client, provider_id, monkeypatch):
    async def resolve(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    assert auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate").json()["status"] == "no_prometheus"
    auth_client.put(f"/api/providers/{provider_id}/monitoring/rules", json={"value": {"enabled": False}})
    assert auth_client.post(f"/api/providers/{provider_id}/monitoring/evaluate").json()["status"] == "disabled"
    rules = auth_client.get(f"/api/providers/{provider_id}/monitoring/rules").json()
    assert rules["last_evaluation"]["status"] == "disabled" and rules["interval_seconds"] == server.MONITORING_EVALUATOR_INTERVAL


# --- node detail, OpenStack layer, Alertmanager, PromQL -------------------------------------------

def test_node_detail_fallback_without_prometheus(auth_client, provider_id, monkeypatch):
    async def resolve(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/nodes/controller-1", params={"range": "6h"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["prometheus"]["status"] == "unavailable" and body["inventory"]["hostname"] == "controller-1"
    assert body["inspection"] == {"series": {"cpu": [], "memory": [], "disk": []}, "latest": None}
    assert auth_client.get(f"/api/providers/{provider_id}/monitoring/nodes/controller-1", params={"range": "2h"}).status_code == 400


def test_node_detail_with_prometheus(auth_client, provider_id, fake_prometheus):
    fake_prometheus["answers"] = {
        'up{job="node_exporter"}': [({"job": "node_exporter", "instance": "192.0.2.11:9100", "nodename": "controller-1"}, 1)],
        "node_filesystem_size_bytes": [({"mountpoint": "/", "device": "/dev/vda1", "fstype": "ext4"}, 100.0), ({"mountpoint": "/data", "device": "/dev/vdb", "fstype": "xfs"}, 200.0)],
        "node_filesystem_avail_bytes": [({"mountpoint": "/"}, 10.0), ({"mountpoint": "/data"}, 150.0)],
        "node_network_receive_bytes_total": [({"device": "ens3"}, 1000.0)], "node_network_transmit_bytes_total": [({"device": "ens3"}, 500.0)],
        "node_network_up": [({"device": "ens3"}, 1)], "node_memory_SwapTotal_bytes": [({}, 0)], "node_filefd_allocated": [({}, 1200)], "node_filefd_maximum": [({}, 100000)],
        "node_load1": [({}, 2.0)], 'mode="idle"})': [({}, 8)],
    }
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/nodes/controller-1", params={"range": "1h"})
    assert response.status_code == 200, response.text
    prom = response.json()["prometheus"]
    assert prom["status"] == "connected" and prom["instance"] == "192.0.2.11:9100"
    assert [fs["mountpoint"] for fs in prom["filesystems"]] == ["/", "/data"] and prom["filesystems"][0]["used_percent"] == 90.0
    assert prom["interfaces"][0]["device"] == "ens3" and prom["interfaces"][0]["rx"] == 1000.0
    assert prom["facts"]["fd_allocated"] == 1200 and prom["facts"]["load1"] == 2.0
    assert set(prom["series"]) == {"cpu", "memory", "iowait", "disk_read", "disk_write", "net_rx", "net_tx", "load1"} and len(prom["series"]["cpu"]) == 61


def test_node_detail_unknown_host(auth_client, provider_id, fake_prometheus):
    fake_prometheus["answers"] = {'up{job="node_exporter"}': [({"job": "node_exporter", "instance": "10.9.9.9:9100", "nodename": "other"}, 1)]}
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/nodes/ghost").json()
    assert body["prometheus"]["status"] == "error" and "ghost" in body["prometheus"]["error"] and body["inventory"] is None


def test_openstack_layer(auth_client, provider_id, fake_prometheus, monkeypatch):
    async def probe(client, vip, key, label, port):
        return {"key": key, "label": label, "port": port, "reachable": key != "swift", "status_code": 300 if key != "swift" else None, "latency_ms": 12 if key != "swift" else None, "scheme": "http", "error": None if key != "swift" else "연결 실패"}
    monkeypatch.setattr(server, "probe_openstack_api", probe)
    fake_prometheus["answers"] = {
        "haproxy_backend_up": [({"backend": "keystone_public"}, 1), ({"backend": "nova_api"}, 0)],
        "haproxy_server_up": [({"backend": "keystone_public", "server": "hcon01"}, 1), ({"backend": "keystone_public", "server": "hcon02"}, 0)],
        "sum(rabbitmq_queue_messages_ready)": [({}, 9)], "sum(rabbitmq_queue_messages_unacked": [({}, 0)], "count(rabbitmq_queue_messages_ready)": [({}, 1152)], "rabbitmq_up": [({"instance": "10.0.0.1:9419"}, 1)],
        "wsrep_cluster_size": [({"instance": "10.0.0.1:9104"}, 3)], "wsrep_local_state": [({"instance": "10.0.0.1:9104"}, 4)], "wsrep_local_recv_queue": [({"instance": "10.0.0.1:9104"}, 0)],
        "wsrep_flow_control_paused": [({"instance": "10.0.0.1:9104"}, 0)], "mysql_up": [({"instance": "10.0.0.1:9104"}, 1)],
    }
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/openstack")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["api_reachable"] == 9 and len(body["api"]) == 10 and body["source"] == "http://prom.test:9090"
    assert body["haproxy"]["status"] == "ok"
    backends = {item["backend"]: item for item in body["haproxy"]["backends"]}
    assert backends["nova_api"]["up"] is False and backends["keystone_public"]["servers_up"] == 1 and backends["keystone_public"]["servers_total"] == 2
    assert body["rabbitmq"]["status"] == "ok" and body["rabbitmq"]["queues"] == 1152
    assert body["galera"]["status"] == "ok" and body["galera"]["cluster_size"] == 3 and body["galera"]["nodes"][0]["state"] == "Synced"


def test_openstack_layer_without_exporters(auth_client, provider_id, monkeypatch):
    async def probe(client, vip, key, label, port):
        return {"key": key, "label": label, "port": port, "reachable": False, "status_code": None, "latency_ms": None, "scheme": None, "error": "연결 실패"}
    async def resolve(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "probe_openstack_api", probe)
    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/openstack").json()
    assert body["api_reachable"] == 0 and body["source"] is None
    assert body["haproxy"]["status"] == "no_source" and "수집원 없음" in body["haproxy"]["note"]
    assert body["rabbitmq"]["status"] == "no_source" and body["galera"]["status"] == "no_source"


def test_alertmanager_unavailable_and_connected(auth_client, provider_id, monkeypatch):
    async def missing(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "resolve_alertmanager", missing)
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/alertmanager").json()
    assert body["status"] == "unavailable" and body["alerts"] == []

    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return [{"labels": {"alertname": "InstanceDown", "severity": "critical", "instance": "10.0.0.5:9100", "job": "node_exporter"}, "annotations": {"summary": "down"}, "status": {"state": "active"}, "startsAt": "2026-09-03T01:00:00Z"},
                    {"labels": {"alertname": "HighLoad", "severity": "warning", "nodename": "hcon01", "extra": "x"}, "annotations": {}, "status": {"state": "active"}, "startsAt": "2026-09-03T02:00:00Z"}]

    async def found(client, provider, nodes):
        return "http://am.test:9093"

    async def fake_get(self, url, params=None):
        return FakeResponse()

    monkeypatch.setattr(server, "resolve_alertmanager", found)
    monkeypatch.setattr(server.httpx.AsyncClient, "get", fake_get)
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/alertmanager").json()
    assert body["status"] == "connected" and body["total"] == 2
    assert body["alerts"][0]["name"] == "InstanceDown" and body["alerts"][0]["severity"] == "critical"
    assert body["alerts"][1]["instance"] == "hcon01" and body["alerts"][1]["labels"] == {"extra": "x"}


def test_promql_query_requires_prometheus_and_validates(auth_client, provider_id, monkeypatch):
    async def resolve(client, provider, nodes):
        return None
    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    assert auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up"}).status_code == 503
    assert auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up", "mode": "bogus"}).status_code == 400
    assert auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up", "range": "3h"}).status_code == 400
    assert auth_client.get(f"/api/providers/{provider_id}/monitoring/query").status_code == 422


def test_promql_query_proxies_and_caps(auth_client, provider_id, monkeypatch):
    async def resolve(client, provider, nodes):
        return "http://prom.test:9090"

    class FakeResponse:
        status_code = 200

        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    async def fake_get(self, url, params=None):
        if url.endswith("/api/v1/query"):
            return FakeResponse({"status": "success", "data": {"resultType": "vector", "result": [{"metric": {"instance": f"i{index}"}, "value": [1, "1"]} for index in range(60)]}})
        return FakeResponse({"status": "success", "data": {"resultType": "matrix", "result": [{"metric": {}, "values": [[1, "1"], [2, "2"]]}]}})

    monkeypatch.setattr(server, "resolve_prometheus", resolve)
    monkeypatch.setattr(server.httpx.AsyncClient, "get", fake_get)
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up"}).json()
    assert body["mode"] == "instant" and len(body["result"]) == 50 and body["truncated"] is True and body["source"] == "http://prom.test:9090"
    body = auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up", "mode": "range", "range": "1h"}).json()
    assert body["result_type"] == "matrix" and body["result"][0]["values"] == [[1.0, "1"], [2.0, "2"]]

    async def failing_get(self, url, params=None):
        return FakeResponse({"status": "error", "errorType": "bad_data", "error": "parse error"})
    monkeypatch.setattr(server.httpx.AsyncClient, "get", failing_get)
    response = auth_client.get(f"/api/providers/{provider_id}/monitoring/query", params={"expr": "up{"})
    assert response.status_code == 400 and "parse error" in response.json()["detail"]


def test_monitoring_routes_require_login(client, provider_id):
    client.cookies.clear()
    for path in ("monitoring/settings", "monitoring/rules", "monitoring/openstack", "monitoring/alertmanager", "monitoring/nodes/controller-1", "monitoring/query?expr=up"):
        assert client.get(f"/api/providers/{provider_id}/{path}").status_code == 401, path
