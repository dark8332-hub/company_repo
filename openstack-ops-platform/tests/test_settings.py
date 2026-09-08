"""Inspection settings and retention maintenance."""
import provider_store
import server


def test_inspection_settings(auth_client):
    body = auth_client.get("/api/settings/inspection").json()
    assert set(body["timeouts"]) == {"node_script", "controller_script", "command", "log_scan", "openstack"}
    assert body["timeouts"] == server.INSPECTION_TIMEOUTS
    assert set(body["retention"]) == {"max_age_days", "raw_age_days", "max_per_provider", "keep_latest"}
    assert body["retention"] == server.RETENTION_POLICY
    assert body["node_concurrency"] == server.INSPECTION_NODE_CONCURRENCY
    assert body["timezone"] == "Asia/Seoul"
    storage = body["storage"]
    assert storage["providers"] == []
    assert storage["total_count"] == 0 and storage["total_bytes"] == 0
    assert storage["db_bytes"] > 0
    # The scheduler task runs the retention prune once right after startup (run_retention_if_due with an
    # empty LAST_PRUNE_AT), so depending on timing last_prune is either still None or an empty run.
    assert storage["last_prune"] is None or storage["last_prune"]["deleted"] == 0


def test_settings_require_login(client):
    assert client.get("/api/settings/inspection").status_code == 401
    assert client.post("/api/settings/retention/prune").status_code == 401


def test_retention_prune_on_empty_db(auth_client):
    response = auth_client.post("/api/settings/retention/prune")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deleted"] == 0 and body["compacted"] == 0 and body["freed_bytes"] == 0
    assert body["policy"] == server.RETENTION_POLICY
    assert body["ran_at"]
    last = body["storage"]["last_prune"]
    assert last["ran_at"] == body["ran_at"]
    assert last["deleted"] == 0
    # The maintenance run is persisted and shows up in the settings storage block.
    assert auth_client.get("/api/settings/inspection").json()["storage"]["last_prune"]["ran_at"] == body["ran_at"]


def test_retention_prune_refused_while_check_running(auth_client):
    server.CHECK_PROGRESS["some-provider"] = {"running": True}
    try:
        assert auth_client.post("/api/settings/retention/prune").status_code == 409
    finally:
        server.CHECK_PROGRESS.clear()


def test_storage_stats_include_provider_rows(auth_client, provider_id):
    storage = auth_client.get("/api/settings/inspection").json()["storage"]
    assert [row["provider_id"] for row in storage["providers"]] == [provider_id]
    assert storage["providers"][0]["count"] == 0


def test_test_database_is_isolated():
    """Guard: the suite must never point at the repository's real data directory."""
    real = server.BASE_DIR / "data"
    assert provider_store.DATA_DIR != real
    assert not str(provider_store.DB_FILE).startswith(str(real))
    assert not str(provider_store.KEY_FILE).startswith(str(real))
