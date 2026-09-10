"""The SPA's cache-busting token must come from the release, not from a hand-typed string.

On 2026-08-26 a browser kept running a cached inspection.js after an upgrade and inspections
stopped starting; the `?v=` values in index.html had not been bumped. The pages now carry a
placeholder that the server fills in, so an upgrade always changes every asset URL.
"""
import re
from pathlib import Path

import pytest
import provider_store
import server

ROOT = Path(__file__).resolve().parents[1]
PAGES = ("index.html", "login.html")
ASSET_QUERY = re.compile(r'(?:src|href)="[^"]+\?v=([^"]*)"')


@pytest.mark.parametrize("page", PAGES)
def test_pages_carry_only_the_placeholder(page):
    values = set(ASSET_QUERY.findall((ROOT / page).read_text(encoding="utf-8")))
    assert values, f"{page} has no versioned asset links"
    assert values == {server.ASSET_VERSION_PLACEHOLDER}, f"{page} still hard-codes a cache-busting value: {values}"


@pytest.mark.parametrize("page", PAGES)
def test_served_pages_resolve_the_placeholder(page):
    rendered = server.rendered_page(page)
    assert server.ASSET_VERSION_PLACEHOLDER not in rendered
    values = set(ASSET_QUERY.findall(rendered))
    assert values == {server.asset_version()}


def test_asset_version_follows_the_release():
    assert server.asset_version().startswith(server.APP_VERSION)


def test_login_page_is_served_with_the_resolved_version(client):
    response = client.get("/login")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert server.ASSET_VERSION_PLACEHOLDER not in response.text
    assert f"?v={server.asset_version()}" in response.text


def test_dashboard_is_served_with_the_resolved_version(auth_client):
    response = auth_client.get("/")
    assert response.status_code == 200
    assert server.ASSET_VERSION_PLACEHOLDER not in response.text
    assert f"js/core.js?v={server.asset_version()}" in response.text


def test_database_uses_wal_and_a_long_busy_timeout():
    """Scheduled checks write multi-megabyte results while operators browse; readers must not block."""
    with provider_store._connect() as connection:
        assert connection.execute("PRAGMA journal_mode").fetchone()[0].lower() == "wal"
    assert provider_store.BUSY_TIMEOUT_SECONDS >= 30


def test_schema_setup_does_not_run_on_every_connection(monkeypatch):
    """~40 statements per connection, and one request opens dozens of them."""
    calls = []
    monkeypatch.setattr(provider_store, "initialize_schema", lambda connection: calls.append(1))
    provider_store._connect().close()
    provider_store._connect().close()
    assert calls == []


def test_schema_is_rebuilt_when_the_database_file_disappears():
    """Ordinary connections skip setup, but a removed file (fresh install, or a test) must not."""
    provider_store._connect().close()
    provider_store.DB_FILE.unlink()
    with provider_store._connect() as connection:
        tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert "providers" in tables and "check_results" in tables
