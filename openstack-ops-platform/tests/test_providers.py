"""Provider endpoints, driven by a provider inserted straight into the store (no SSH)."""
import uuid

import pytest

import provider_store
import server
from conftest import FAKE_NODES, FAKE_PROVIDER, far_run_time

MISSING = str(uuid.uuid4())


def test_providers_empty(auth_client):
    assert auth_client.get("/api/providers").json() == {"providers": []}


@pytest.mark.parametrize("suffix", ["/overview", "/checks", "/nodes", "/check-exceptions", "/custom-checks",
                                    "/log-exclusions", "/check-schedule", "/checks/progress", "/latest-check",
                                    "/host-keys", "/database-credentials", "/sudo-credentials"])
def test_unknown_provider_404(auth_client, suffix):
    response = auth_client.get(f"/api/providers/{MISSING}{suffix}")
    assert response.status_code == 404, (suffix, response.text)


def test_unknown_provider_delete_404(auth_client):
    assert auth_client.delete(f"/api/providers/{MISSING}").status_code == 404


def test_unknown_provider_schedule_put_404(auth_client):
    response = auth_client.put(f"/api/providers/{MISSING}/check-schedule", json={"enabled": False})
    assert response.status_code == 404


def test_provider_listed(auth_client, provider_id):
    body = auth_client.get("/api/providers").json()
    assert len(body["providers"]) == 1
    provider = body["providers"][0]
    assert provider["id"] == provider_id
    assert provider["name"] == FAKE_PROVIDER["name"]
    assert provider["vip"] == FAKE_PROVIDER["vip"]
    assert provider["available_tools"] == FAKE_PROVIDER["available_tools"]
    assert provider["latest_check"] is None
    assert provider["database_credentials_configured"] is False
    assert provider["sudo_password_configured"] is False
    assert "credentials" not in provider
    assert auth_client.get("/api/health").json()["providers"] == 1


def test_provider_nodes(auth_client, provider_id):
    body = auth_client.get(f"/api/providers/{provider_id}/nodes").json()
    assert body["provider_id"] == provider_id
    assert body["count"] == len(FAKE_NODES)
    # controllers first, then by hostname
    assert [node["hostname"] for node in body["nodes"]] == ["controller-1", "controller-2", "compute-1"]
    assert body["nodes"][0]["address"] == "192.0.2.11"


def test_provider_host_keys_seeded_from_registration(auth_client, provider_id):
    body = auth_client.get(f"/api/providers/{provider_id}/host-keys").json()
    fingerprints = [key["fingerprint"] for key in body.get("keys", body.get("host_keys", []))]
    assert FAKE_PROVIDER["fingerprint"] in fingerprints


def test_check_exceptions_crud(auth_client, provider_id):
    url = f"/api/providers/{provider_id}/check-exceptions"
    assert auth_client.get(url).json() == {"exceptions": []}
    created = auth_client.post(url, json={"item_key": "chrony", "reason": "NTP handled externally"})
    assert created.status_code == 200, created.text
    exception_id = created.json()["id"] if "id" in created.json() else created.json()["exception"]["id"]
    listed = auth_client.get(url).json()["exceptions"]
    assert [item["item_key"] for item in listed] == ["chrony"]
    assert auth_client.delete(f"{url}/{exception_id}").status_code == 200
    assert auth_client.get(url).json() == {"exceptions": []}
    assert auth_client.delete(f"{url}/{exception_id}").status_code == 404


def test_check_exception_rejects_unknown_item(auth_client, provider_id):
    response = auth_client.post(f"/api/providers/{provider_id}/check-exceptions", json={"item_key": "not_a_check", "reason": "x"})
    assert response.status_code in (400, 422), response.text


def test_custom_checks_crud(auth_client, provider_id):
    url = f"/api/providers/{provider_id}/custom-checks"
    assert auth_client.get(url).json() == {"checks": []}
    payload = {"name": "uptime", "command": "uptime", "target_role": "all", "rule_type": "exit_code"}
    created = auth_client.post(url, json=payload)
    assert created.status_code == 200, created.text
    check = created.json()
    assert check["key"] == f"custom:{check['id']}"
    assert check["enabled"] is True
    listed = auth_client.get(url).json()["checks"]
    assert [item["id"] for item in listed] == [check["id"]]
    updated = auth_client.put(f"{url}/{check['id']}", json={**payload, "name": "uptime2", "enabled": False})
    assert updated.status_code == 200
    assert updated.json()["name"] == "uptime2" and updated.json()["enabled"] is False
    assert auth_client.put(f"{url}/{MISSING}", json=payload).status_code == 404
    assert auth_client.delete(f"{url}/{check['id']}").status_code == 200
    assert auth_client.get(url).json() == {"checks": []}
    assert auth_client.delete(f"{url}/{check['id']}").status_code == 404


@pytest.mark.parametrize("command", ["rm -rf /", "uptime; reboot", "systemctl restart nova", "df | grep x", "openstack server delete x"])
def test_custom_check_rejects_unsafe_commands(auth_client, provider_id, command):
    response = auth_client.post(f"/api/providers/{provider_id}/custom-checks", json={"name": "bad", "command": command})
    assert response.status_code == 422, response.text


def test_custom_check_contains_requires_expected_value(auth_client, provider_id):
    response = auth_client.post(f"/api/providers/{provider_id}/custom-checks", json={"name": "x", "command": "uptime", "rule_type": "contains"})
    assert response.status_code == 422


def test_log_exclusions_crud(auth_client, provider_id):
    url = f"/api/providers/{provider_id}/log-exclusions"
    body = auth_client.get(url).json()
    assert body["exclusions"] == []
    assert body["services"] == list(server.LOG_SERVICES)
    created = auth_client.post(url, json={"service": "nova", "pattern": "known noisy warning", "reason": "vendor bug"})
    assert created.status_code == 200, created.text
    exclusion_id = created.json()["id"] if "id" in created.json() else created.json()["exclusion"]["id"]
    assert [item["pattern"] for item in auth_client.get(url).json()["exclusions"]] == ["known noisy warning"]
    assert auth_client.delete(f"{url}/{exclusion_id}").status_code == 200
    assert auth_client.get(url).json()["exclusions"] == []
    assert auth_client.delete(f"{url}/{exclusion_id}").status_code == 404


@pytest.mark.parametrize("pattern", ["(unclosed", "line1\nline2"])
def test_log_exclusion_rejects_bad_pattern(auth_client, provider_id, pattern):
    response = auth_client.post(f"/api/providers/{provider_id}/log-exclusions", json={"service": "nova", "pattern": pattern, "reason": "x"})
    assert response.status_code in (400, 422), response.text


def test_log_exclusion_rejects_unknown_service(auth_client, provider_id):
    response = auth_client.post(f"/api/providers/{provider_id}/log-exclusions", json={"service": "bogus", "pattern": "x", "reason": "y"})
    assert response.status_code in (400, 422), response.text


def test_check_schedule_default_and_update(auth_client, provider_id):
    url = f"/api/providers/{provider_id}/check-schedule"
    body = auth_client.get(url).json()
    assert body["enabled"] is False
    assert body["run_time"] == "09:00"
    assert body["selected_items"] is None
    assert body["next_run_at"] is None
    assert body["timezone"] == "Asia/Seoul"
    assert body["server_time"]

    run_time = far_run_time()
    updated = auth_client.put(url, json={"enabled": True, "run_time": run_time, "selected_items": ["memory", "cpu", "bogus_key"]})
    assert updated.status_code == 200, updated.text
    body = updated.json()
    assert body["enabled"] is True
    assert body["run_time"] == run_time
    assert body["selected_items"] == ["cpu", "memory"]  # unknown keys dropped, sorted
    assert body["next_run_at"] and body["next_run_at"].endswith("+09:00")
    assert body["next_run_at"][11:16] == run_time
    assert auth_client.get(url).json()["enabled"] is True

    disabled = auth_client.put(url, json={"enabled": False, "run_time": "08:15"})
    assert disabled.json()["enabled"] is False and disabled.json()["next_run_at"] is None
    assert provider_store.list_enabled_check_schedules() == []


def test_check_schedule_validation(auth_client, provider_id):
    url = f"/api/providers/{provider_id}/check-schedule"
    assert auth_client.put(url, json={"enabled": True, "run_time": "25:00"}).status_code == 422
    assert auth_client.put(url, json={"enabled": True, "run_time": "9:00"}).status_code == 422
    # Enabling with only unknown keys leaves nothing to run -> 400
    response = auth_client.put(url, json={"enabled": True, "run_time": "09:00", "selected_items": ["nope"]})
    assert response.status_code == 400


def test_overview_without_checks(auth_client, provider_id):
    body = auth_client.get(f"/api/providers/{provider_id}/overview").json()
    assert body["provider"]["id"] == provider_id
    assert body["provider"]["inventory"] == {"total": 3, "controller": 2, "compute": 1}
    assert body["latest"] is None
    assert body["history"] == []
    assert body["items"] == {}
    assert body["issue_items"] == []
    assert body["node_snapshot"] is None
    assert body["alerts"] == {"active": 0, "critical": 0, "warning": 0, "recent": []}
    assert body["schedule"]["enabled"] is False
    assert body["work_histories"] == []
    assert body["running"] is False


def test_checks_list_empty(auth_client, provider_id):
    body = auth_client.get(f"/api/providers/{provider_id}/checks").json()
    assert body == {"provider_id": provider_id, "checks": [], "count": 0}
    assert auth_client.get(f"/api/providers/{provider_id}/checks", params={"limit": 0}).status_code == 422
    assert auth_client.get(f"/api/providers/{provider_id}/checks/{MISSING}").status_code == 404


def test_check_progress_idle(auth_client, provider_id):
    body = auth_client.get(f"/api/providers/{provider_id}/checks/progress").json()
    assert body["running"] is False and body["stage"] == "idle" and body["percent"] == 0


def test_latest_check_none(auth_client, provider_id):
    response = auth_client.get(f"/api/providers/{provider_id}/latest-check")
    assert response.status_code in (200, 404), response.text


def test_credential_status_endpoints(auth_client, provider_id):
    db = auth_client.get(f"/api/providers/{provider_id}/database-credentials").json()
    assert db["configured"] is False
    sudo = auth_client.get(f"/api/providers/{provider_id}/sudo-credentials").json()
    assert sudo.get("sudo_password_configured", sudo.get("configured")) is False


def test_delete_provider_cascades(auth_client, provider_id):
    auth_client.post(f"/api/providers/{provider_id}/check-exceptions", json={"item_key": "cpu", "reason": "r"})
    auth_client.put(f"/api/providers/{provider_id}/check-schedule", json={"enabled": True, "run_time": far_run_time(), "selected_items": ["cpu"]})
    response = auth_client.delete(f"/api/providers/{provider_id}")
    assert response.status_code == 200
    assert response.json() == {"status": "deleted", "provider_id": provider_id}
    assert auth_client.get("/api/providers").json() == {"providers": []}
    assert auth_client.get(f"/api/providers/{provider_id}/overview").status_code == 404
    assert provider_store.list_provider_nodes(provider_id) == []
    assert provider_store.list_check_exceptions(provider_id) == []
    assert provider_store.list_enabled_check_schedules() == []
    assert auth_client.delete(f"/api/providers/{provider_id}").status_code == 404


def test_connect_provider_validation_does_not_touch_network(auth_client):
    # Model validation fails before any SSH is attempted.
    response = auth_client.post("/api/providers/connect", json={"vip": "192.0.2.1", "username": "u", "auth_method": "private_key"})
    assert response.status_code == 422
    response = auth_client.post("/api/providers/connect", json={"vip": "bad host!", "username": "u", "auth_method": "password", "password": "p"})
    assert response.status_code == 422
    response = auth_client.post("/api/providers/connect", json={"vip": "192.0.2.1", "username": "u", "auth_method": "kerberos"})
    assert response.status_code == 422
