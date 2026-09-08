"""Shared fixtures for the HTTP API regression suite.

Isolation strategy (important, keep this order):
  1. `provider_store` computes DATA_DIR / KEY_FILE / DB_FILE at *import time* from the
     APP_DATA_DIR env var. So we set APP_DATA_DIR to a fresh temp directory BEFORE the first
     import of `provider_store` or `server`. This keeps the real data/providers.db and
     data/.master_key untouched (a brand-new Fernet key is generated inside the temp dir).
  2. `server.ensure_administrator` (startup event) reads ADMIN_USERNAME / ADMIN_PASSWORD from
     the environment, so those are fixed to known test values before `server` is imported.
     ADMIN_PASSWORD_RESET is removed so the startup path is the plain "create if missing" one.
  3. One `TestClient(app)` context is opened per session so the real startup events run once
     (admin account creation, alert backfill, scheduler task). Every test then starts from a
     clean database: the autouse fixture empties every table and re-seeds the admin account
     through the same store function the startup hook uses (must_change_password=True), and
     clears in-memory server state (login lockouts, check progress, client cookies).
  4. The scheduler task started by `start_check_scheduler` lives in the session client's event
     loop. Against a database with no enabled schedule it is idle; tests that enable a schedule
     use `far_run_time()` (12 h away) so it can never fire a real SSH check during the run, and
     LAST_PRUNE_AT is pinned to "now" so the daily retention prune cannot race a test either.
"""
from __future__ import annotations

import atexit
import os
import shutil
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TEST_DATA_DIR = Path(tempfile.mkdtemp(prefix="ops-platform-tests-"))
atexit.register(shutil.rmtree, TEST_DATA_DIR, True)

ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "TestAdmin123!"

# --- environment must be prepared before importing the application modules -------------------
os.environ["APP_DATA_DIR"] = str(TEST_DATA_DIR)
os.environ["ADMIN_USERNAME"] = ADMIN_USERNAME
os.environ["ADMIN_PASSWORD"] = ADMIN_PASSWORD
os.environ.pop("ADMIN_PASSWORD_RESET", None)
os.environ.pop("SESSION_COOKIE_SECURE", None)
os.environ["INSPECTION_TIMEZONE"] = "Asia/Seoul"

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

for _name in ("provider_store", "server"):
    if _name in sys.modules:  # pragma: no cover - guards against a stray earlier import
        raise RuntimeError(f"{_name} was imported before the test environment was prepared")

import provider_store  # noqa: E402
import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

REAL_DATA_DIR = PROJECT_ROOT / "data"
assert provider_store.DATA_DIR == TEST_DATA_DIR, provider_store.DATA_DIR
assert provider_store.DB_FILE.parent == TEST_DATA_DIR
assert provider_store.KEY_FILE.parent == TEST_DATA_DIR
assert not str(provider_store.DB_FILE).startswith(str(REAL_DATA_DIR))

STARTUP_STATE: dict = {}


def login(client: TestClient, username: str = ADMIN_USERNAME, password: str = ADMIN_PASSWORD):
    return client.post("/api/auth/login", json={"username": username, "password": password})


def far_run_time() -> str:
    """An HH:MM 12 hours away from the scheduler clock, so an enabled schedule never fires during the run."""
    return (datetime.now(server.schedule_timezone()) + timedelta(hours=12)).strftime("%H:%M")


def reset_database() -> None:
    """Empty every table (schema kept) and re-seed the admin account exactly as startup does."""
    with provider_store._connect() as connection:
        tables = [row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
        for table in tables:
            if table != "schema_migrations":
                connection.execute(f'DELETE FROM "{table}"')
    provider_store.ensure_admin_account(ADMIN_USERNAME, ADMIN_PASSWORD, must_change_password=True)


@pytest.fixture(scope="session")
def app_client():
    """One client for the whole session; entering the context runs the app's startup events."""
    try:
        provider_store.DB_FILE.unlink()
    except FileNotFoundError:
        pass
    with TestClient(server.app) as test_client:
        STARTUP_STATE["admin"] = provider_store.admin_account_info()
        # Pin the daily prune so the scheduler task never runs it in the middle of a test.
        server.LAST_PRUNE_AT["at"] = datetime.now(timezone.utc)
        yield test_client


@pytest.fixture(autouse=True)
def fresh_state(app_client):
    """Clean database + cleared in-memory server state for every test."""
    reset_database()
    server.LOGIN_FAILURES.clear()
    server.CHECK_PROGRESS.clear()
    server.LAST_PRUNE_AT["at"] = datetime.now(timezone.utc)
    app_client.cookies.clear()
    yield
    server.LOGIN_FAILURES.clear()
    server.CHECK_PROGRESS.clear()
    app_client.cookies.clear()


@pytest.fixture
def client(app_client):
    """Unauthenticated client (no session cookie)."""
    return app_client


@pytest.fixture
def auth_client(client):
    response = login(client)
    assert response.status_code == 200, response.text
    assert server.SESSION_COOKIE in client.cookies
    return client


FAKE_PROVIDER = {
    "name": "Test Provider",
    "vip": "192.0.2.10",
    "port": 22,
    "username": "stack",
    "auth_method": "password",
    "fingerprint": "SHA256:testfingerprintdoesnotmatter0000000000000",
    "controller_hostname": "controller-1",
    "sudo_mode": "root",
    "available_tools": ["openstack", "pcs"],
}
FAKE_NODES = [
    {"hostname": "controller-1", "role": "controller", "address": "192.0.2.11", "source": "test"},
    {"hostname": "controller-2", "role": "controller", "address": "192.0.2.12", "source": "test"},
    {"hostname": "compute-1", "role": "compute", "address": "192.0.2.21", "source": "test"},
]


@pytest.fixture
def provider_id(auth_client) -> str:
    """A provider inserted straight into the store (no SSH), with three discovered nodes."""
    new_id = provider_store.save_provider(dict(FAKE_PROVIDER), {"password": "not-a-real-password"})
    provider_store.save_provider_nodes(new_id, [dict(node) for node in FAKE_NODES])
    return new_id
