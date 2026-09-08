import hashlib
import hmac
import json
import os
import secrets
import shutil
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography.fernet import Fernet

DATA_DIR = Path(os.getenv("APP_DATA_DIR", Path(__file__).parent / "data"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
KEY_FILE = DATA_DIR / ".master_key"
DB_FILE = DATA_DIR / "providers.db"


def _cipher() -> Fernet:
    if not KEY_FILE.exists():
        KEY_FILE.write_bytes(Fernet.generate_key())
        KEY_FILE.chmod(0o600)
    return Fernet(KEY_FILE.read_bytes().strip())


def _connect() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_FILE)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA secure_delete=ON")
    connection.execute("""CREATE TABLE IF NOT EXISTS providers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, vip TEXT NOT NULL, port INTEGER NOT NULL,
        username TEXT NOT NULL, auth_method TEXT NOT NULL, credentials BLOB NOT NULL,
        fingerprint TEXT NOT NULL, controller_hostname TEXT NOT NULL,
        sudo_mode TEXT NOT NULL, available_tools TEXT NOT NULL, created_at TEXT NOT NULL
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS check_results (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, status TEXT NOT NULL,
        result TEXT NOT NULL, checked_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS provider_nodes (
        provider_id TEXT NOT NULL, hostname TEXT NOT NULL, role TEXT NOT NULL,
        address TEXT NOT NULL, source TEXT NOT NULL, discovered_at TEXT NOT NULL,
        PRIMARY KEY(provider_id, hostname),
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS check_exceptions (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, item_key TEXT NOT NULL,
        node_hostname TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL, created_at TEXT NOT NULL,
        UNIQUE(provider_id, item_key, node_hostname),
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS custom_checks (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '', target_role TEXT NOT NULL,
        command TEXT NOT NULL, execution_context TEXT NOT NULL DEFAULT 'plain',
        rule_type TEXT NOT NULL, expected_value TEXT NOT NULL DEFAULT '',
        timeout_seconds INTEGER NOT NULL DEFAULT 20, enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS provider_host_keys (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, fingerprint TEXT NOT NULL,
        hostname TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
        approved_at TEXT NOT NULL, last_seen_at TEXT NOT NULL,
        UNIQUE(provider_id, fingerprint),
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS host_key_events (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, fingerprint TEXT NOT NULL,
        action TEXT NOT NULL, hostname TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS provider_database_credentials (
        provider_id TEXT PRIMARY KEY, credentials BLOB NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS work_histories (
        id TEXT PRIMARY KEY, provider_id TEXT, title TEXT NOT NULL, work_type TEXT NOT NULL,
        status TEXT NOT NULL, operator TEXT NOT NULL, target TEXT NOT NULL DEFAULT '',
        ticket TEXT NOT NULL DEFAULT '', description TEXT NOT NULL, commands TEXT NOT NULL DEFAULT '',
        before_state TEXT NOT NULL DEFAULT '', after_state TEXT NOT NULL DEFAULT '',
        result TEXT NOT NULL DEFAULT '', follow_up TEXT NOT NULL DEFAULT '',
        started_at TEXT NOT NULL, completed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS alerts (
        id TEXT PRIMARY KEY, provider_id TEXT, check_id TEXT, source_key TEXT NOT NULL,
        category TEXT NOT NULL, severity TEXT NOT NULL, status TEXT NOT NULL,
        title TEXT NOT NULL, description TEXT NOT NULL, target TEXT NOT NULL DEFAULT '',
        assignee TEXT NOT NULL DEFAULT '', work_history_id TEXT,
        first_detected_at TEXT NOT NULL, last_detected_at TEXT NOT NULL,
        acknowledged_at TEXT, resolved_at TEXT, resolution_note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(provider_id) REFERENCES providers(id),
        FOREIGN KEY(work_history_id) REFERENCES work_histories(id)
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_alerts_status_detected ON alerts(status,last_detected_at DESC)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_alerts_provider_source ON alerts(provider_id,source_key)")
    connection.execute("CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL)")
    migration = "provider_host_keys_v1"
    if not connection.execute("SELECT 1 FROM schema_migrations WHERE name=?", (migration,)).fetchone():
        now = datetime.now(timezone.utc).isoformat()
        connection.execute("""INSERT OR IGNORE INTO provider_host_keys
            (id,provider_id,fingerprint,hostname,address,approved_at,last_seen_at)
            SELECT lower(hex(randomblob(16))),id,fingerprint,controller_hostname,vip,created_at,?
            FROM providers WHERE fingerprint != ''""", (now,))
        connection.execute("INSERT INTO schema_migrations VALUES (?,?)", (migration, now))
    exception_columns = {row[1] for row in connection.execute("PRAGMA table_info(check_exceptions)")}
    if "node_hostname" not in exception_columns:
        connection.execute("ALTER TABLE check_exceptions RENAME TO check_exceptions_legacy")
        connection.execute("""CREATE TABLE check_exceptions (
            id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, item_key TEXT NOT NULL,
            node_hostname TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL, created_at TEXT NOT NULL,
            UNIQUE(provider_id, item_key, node_hostname),
            FOREIGN KEY(provider_id) REFERENCES providers(id)
        )""")
        connection.execute("""INSERT INTO check_exceptions (id,provider_id,item_key,node_hostname,reason,created_at)
            SELECT id,provider_id,item_key,'',reason,created_at FROM check_exceptions_legacy""")
        connection.execute("DROP TABLE check_exceptions_legacy")
    custom_columns = {row[1] for row in connection.execute("PRAGMA table_info(custom_checks)")}
    if "execution_context" not in custom_columns:
        connection.execute("ALTER TABLE custom_checks ADD COLUMN execution_context TEXT NOT NULL DEFAULT 'plain'")
    node_columns = {row[1] for row in connection.execute("PRAGMA table_info(provider_nodes)")}
    if "maintenance" not in node_columns:
        connection.execute("ALTER TABLE provider_nodes ADD COLUMN maintenance INTEGER NOT NULL DEFAULT 0")
    if "note" not in node_columns:
        connection.execute("ALTER TABLE provider_nodes ADD COLUMN note TEXT NOT NULL DEFAULT ''")
    provider_columns = {row[1] for row in connection.execute("PRAGMA table_info(providers)")}
    if "updated_at" not in provider_columns:
        connection.execute("ALTER TABLE providers ADD COLUMN updated_at TEXT")
    check_columns = {row[1] for row in connection.execute("PRAGMA table_info(check_results)")}
    if "summary" not in check_columns:
        connection.execute("ALTER TABLE check_results ADD COLUMN summary TEXT")
    if "compacted_at" not in check_columns:
        connection.execute("ALTER TABLE check_results ADD COLUMN compacted_at TEXT")
    connection.execute("""CREATE TABLE IF NOT EXISTS log_exclusions (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, service TEXT NOT NULL DEFAULT '',
        pattern TEXT NOT NULL, reason TEXT NOT NULL, created_at TEXT NOT NULL,
        UNIQUE(provider_id, service, pattern),
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("CREATE TABLE IF NOT EXISTS maintenance_runs (name TEXT PRIMARY KEY, ran_at TEXT NOT NULL, detail TEXT NOT NULL)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_check_results_provider_checked ON check_results(provider_id,checked_at DESC)")
    connection.execute("""CREATE TABLE IF NOT EXISTS check_schedules (
        provider_id TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0, run_time TEXT NOT NULL DEFAULT '09:00',
        selected_items TEXT, last_run_at TEXT, last_status TEXT, last_check_id TEXT, last_error TEXT, updated_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    # Single administrator account (id is fixed to 1) and its server-side login sessions.
    connection.execute("""CREATE TABLE IF NOT EXISTS admin_account (
        id INTEGER PRIMARY KEY CHECK(id = 1), username TEXT NOT NULL, password_hash BLOB NOT NULL, salt BLOB NOT NULL,
        must_change_password INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, password_changed_at TEXT NOT NULL, last_login_at TEXT
    )""")
    # Server-side platform settings (JSON values keyed by setting name) and the operator audit trail.
    connection.execute("""CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL, updated_by TEXT NOT NULL DEFAULT ''
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL,
        target_type TEXT NOT NULL DEFAULT '', target_id TEXT NOT NULL DEFAULT '', target_name TEXT NOT NULL DEFAULT '',
        detail TEXT NOT NULL DEFAULT '', outcome TEXT NOT NULL DEFAULT 'success', remote_addr TEXT NOT NULL DEFAULT '', user_agent TEXT NOT NULL DEFAULT ''
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action, created_at DESC)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id)")
    # Work history extensions: approval flow, before/after inspections and file attachments.
    work_columns = {row[1] for row in connection.execute("PRAGMA table_info(work_histories)")}
    for column, definition in (("approved_by", "TEXT NOT NULL DEFAULT ''"), ("approved_at", "TEXT"), ("before_check_id", "TEXT"), ("after_check_id", "TEXT")):
        if column not in work_columns:
            connection.execute(f"ALTER TABLE work_histories ADD COLUMN {column} {definition}")
    connection.execute("""CREATE TABLE IF NOT EXISTS work_history_attachments (
        id TEXT PRIMARY KEY, history_id TEXT NOT NULL, filename TEXT NOT NULL, content_type TEXT NOT NULL DEFAULT '',
        size INTEGER NOT NULL DEFAULT 0, stored_name TEXT NOT NULL, uploaded_by TEXT NOT NULL DEFAULT '', uploaded_at TEXT NOT NULL,
        FOREIGN KEY(history_id) REFERENCES work_histories(id)
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_work_attachments_history ON work_history_attachments(history_id)")
    # Alerts extensions: maintenance windows suppress matching alerts, alert_events keep a per-alert timeline.
    connection.execute("""CREATE TABLE IF NOT EXISTS maintenance_windows (
        id TEXT PRIMARY KEY, provider_id TEXT, title TEXT NOT NULL, starts_at TEXT NOT NULL, ends_at TEXT NOT NULL,
        nodes TEXT NOT NULL DEFAULT '[]', item_keys TEXT NOT NULL DEFAULT '[]', work_history_id TEXT, note TEXT NOT NULL DEFAULT '',
        created_by TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS alert_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT, alert_id TEXT NOT NULL, created_at TEXT NOT NULL, actor TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL, text TEXT NOT NULL DEFAULT ''
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_alert_events_alert ON alert_events(alert_id, id)")
    alert_columns = {row[1] for row in connection.execute("PRAGMA table_info(alerts)")}
    if "suppressed_until" not in alert_columns:
        connection.execute("ALTER TABLE alerts ADD COLUMN suppressed_until TEXT")
    connection.execute("""CREATE TABLE IF NOT EXISTS auth_sessions (
        token_hash TEXT PRIMARY KEY, username TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL, remote_addr TEXT NOT NULL DEFAULT '', user_agent TEXT NOT NULL DEFAULT ''
    )""")
    return connection


# --- Administrator account and login sessions -------------------------------------------------

def _hash_password(password: str, salt: bytes) -> bytes:
    return hashlib.scrypt(password.encode("utf-8"), salt=salt, n=2 ** 14, r=8, p=1, dklen=64)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def admin_account_info() -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT username, must_change_password, created_at, password_changed_at, last_login_at FROM admin_account WHERE id=1").fetchone()
    if not row:
        return None
    return {
        "username": row["username"], "must_change_password": bool(row["must_change_password"]), "created_at": row["created_at"],
        "password_changed_at": row["password_changed_at"], "last_login_at": row["last_login_at"],
    }


def ensure_admin_account(username: str, password: str, must_change_password: bool) -> bool:
    """Create the administrator account when none exists. Returns True when it was created."""
    now = datetime.now(timezone.utc).isoformat()
    salt = secrets.token_bytes(16)
    with _connect() as connection:
        if connection.execute("SELECT 1 FROM admin_account WHERE id=1").fetchone():
            return False
        connection.execute(
            "INSERT INTO admin_account (id, username, password_hash, salt, must_change_password, created_at, password_changed_at) VALUES (1,?,?,?,?,?,?)",
            (username, _hash_password(password, salt), salt, int(must_change_password), now, now),
        )
    return True


def reset_admin_password(username: str, password: str, must_change_password: bool = True) -> None:
    """Operator-initiated reset (ADMIN_PASSWORD_RESET): replaces the credentials and revokes every session."""
    now = datetime.now(timezone.utc).isoformat()
    salt = secrets.token_bytes(16)
    with _connect() as connection:
        connection.execute(
            "INSERT INTO admin_account (id, username, password_hash, salt, must_change_password, created_at, password_changed_at) VALUES (1,?,?,?,?,?,?) "
            "ON CONFLICT(id) DO UPDATE SET username=excluded.username, password_hash=excluded.password_hash, salt=excluded.salt, "
            "must_change_password=excluded.must_change_password, password_changed_at=excluded.password_changed_at",
            (username, _hash_password(password, salt), salt, int(must_change_password), now, now),
        )
        connection.execute("DELETE FROM auth_sessions")


def verify_admin_password(username: str, password: str) -> dict | None:
    """Constant-time credential check; returns the account info on success, None otherwise."""
    with _connect() as connection:
        row = connection.execute("SELECT username, password_hash, salt, must_change_password FROM admin_account WHERE id=1").fetchone()
    if not row:
        return None
    candidate = _hash_password(password, bytes(row["salt"]))
    username_ok = hmac.compare_digest(username.encode("utf-8"), row["username"].encode("utf-8"))
    password_ok = hmac.compare_digest(candidate, bytes(row["password_hash"]))
    if not (username_ok and password_ok):
        return None
    return {"username": row["username"], "must_change_password": bool(row["must_change_password"])}


def change_admin_password(new_password: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    salt = secrets.token_bytes(16)
    with _connect() as connection:
        connection.execute(
            "UPDATE admin_account SET password_hash=?, salt=?, must_change_password=0, password_changed_at=? WHERE id=1",
            (_hash_password(new_password, salt), salt, now),
        )


def create_session(username: str, ttl_hours: int, remote_addr: str = "", user_agent: str = "") -> tuple[str, str]:
    """Returns (token, expires_at). Only the SHA-256 of the token is stored."""
    token = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)
    expires_at = (now + timedelta(hours=ttl_hours)).isoformat()
    with _connect() as connection:
        connection.execute(
            "INSERT INTO auth_sessions (token_hash, username, created_at, expires_at, last_seen_at, remote_addr, user_agent) VALUES (?,?,?,?,?,?,?)",
            (_token_hash(token), username, now.isoformat(), expires_at, now.isoformat(), remote_addr[:64], user_agent[:256]),
        )
        connection.execute("UPDATE admin_account SET last_login_at=? WHERE id=1 AND username=?", (now.isoformat(), username))
    return token, expires_at


def get_session(token: str) -> dict | None:
    if not token:
        return None
    now = datetime.now(timezone.utc)
    with _connect() as connection:
        row = connection.execute(
            "SELECT s.token_hash, s.username, s.created_at, s.expires_at, s.last_seen_at, a.must_change_password FROM auth_sessions s "
            "JOIN admin_account a ON a.username = s.username WHERE s.token_hash=?", (_token_hash(token),)
        ).fetchone()
        if not row:
            return None
        if datetime.fromisoformat(row["expires_at"]) <= now:
            connection.execute("DELETE FROM auth_sessions WHERE token_hash=?", (row["token_hash"],))
            return None
        # Touch at most once a minute to keep the write load negligible.
        if (now - datetime.fromisoformat(row["last_seen_at"])).total_seconds() > 60:
            connection.execute("UPDATE auth_sessions SET last_seen_at=? WHERE token_hash=?", (now.isoformat(), row["token_hash"]))
    return {
        "username": row["username"], "created_at": row["created_at"], "expires_at": row["expires_at"],
        "must_change_password": bool(row["must_change_password"]),
    }


def delete_session(token: str) -> None:
    if not token:
        return
    with _connect() as connection:
        connection.execute("DELETE FROM auth_sessions WHERE token_hash=?", (_token_hash(token),))


def delete_other_sessions(keep_token: str) -> int:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM auth_sessions WHERE token_hash<>?", (_token_hash(keep_token),))
        return cursor.rowcount


def purge_expired_sessions() -> int:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM auth_sessions WHERE expires_at<=?", (datetime.now(timezone.utc).isoformat(),))
        return cursor.rowcount


def active_session_count() -> int:
    with _connect() as connection:
        return connection.execute("SELECT COUNT(*) FROM auth_sessions WHERE expires_at>?", (datetime.now(timezone.utc).isoformat(),)).fetchone()[0]


def save_provider(data: dict, credentials: dict) -> str:
    provider_id = str(uuid.uuid4())
    encrypted = _cipher().encrypt(json.dumps(credentials).encode())
    created_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("INSERT INTO providers (id,name,vip,port,username,auth_method,credentials,fingerprint,controller_hostname,sudo_mode,available_tools,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (
            provider_id, data["name"], data["vip"], data["port"], data["username"],
            data["auth_method"], encrypted, data["fingerprint"], data["controller_hostname"],
            data["sudo_mode"], json.dumps(data["available_tools"]), created_at,
        ))
        connection.execute("INSERT INTO provider_host_keys VALUES (?,?,?,?,?,?,?)", (
            str(uuid.uuid4()), provider_id, data["fingerprint"], data["controller_hostname"], data["vip"], created_at, created_at,
        ))
        connection.execute("INSERT INTO host_key_events VALUES (?,?,?,?,?,?,?)", (
            str(uuid.uuid4()), provider_id, data["fingerprint"], "approved", data["controller_hostname"], data["vip"], created_at,
        ))
    return provider_id


def list_providers() -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT id,name,vip,port,username,auth_method,controller_hostname,sudo_mode,available_tools,created_at FROM providers ORDER BY created_at DESC").fetchall()
    return [{**dict(row), "available_tools": json.loads(row["available_tools"])} for row in rows]


def get_provider(provider_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT * FROM providers WHERE id=?", (provider_id,)).fetchone()
    if not row:
        return None
    data = dict(row)
    data["available_tools"] = json.loads(data["available_tools"])
    data["credentials"] = json.loads(_cipher().decrypt(data["credentials"]).decode())
    data["database_credentials"] = get_database_credentials(provider_id)
    return data


def save_database_credentials(provider_id: str, credentials: dict) -> None:
    encrypted = _cipher().encrypt(json.dumps(credentials).encode())
    updated_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("""INSERT INTO provider_database_credentials (provider_id,credentials,updated_at)
            VALUES (?,?,?) ON CONFLICT(provider_id) DO UPDATE SET
            credentials=excluded.credentials,updated_at=excluded.updated_at""",
            (provider_id, encrypted, updated_at),
        )


def get_database_credentials(provider_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute(
            "SELECT credentials FROM provider_database_credentials WHERE provider_id=?", (provider_id,),
        ).fetchone()
    if not row:
        return None
    return json.loads(_cipher().decrypt(row["credentials"]).decode())


def database_credentials_status(provider_id: str) -> dict:
    credentials = get_database_credentials(provider_id)
    return {
        "configured": credentials is not None,
        "username": credentials.get("username", "") if credentials else "",
        "host": credentials.get("host", "localhost") if credentials else "localhost",
        "port": credentials.get("port", 3306) if credentials else 3306,
    }


def update_provider_sudo(provider_id: str, sudo_password: str | None, sudo_mode: str) -> None:
    """Store (or clear) the sudo password inside the encrypted credential blob and record the sudo mode."""
    with _connect() as connection:
        row = connection.execute("SELECT credentials FROM providers WHERE id=?", (provider_id,)).fetchone()
        if not row:
            raise KeyError(provider_id)
        credentials = json.loads(_cipher().decrypt(row["credentials"]).decode())
        if sudo_password:
            credentials["sudo_password"] = sudo_password
        else:
            credentials.pop("sudo_password", None)
        encrypted = _cipher().encrypt(json.dumps(credentials).encode())
        connection.execute("UPDATE providers SET credentials=?, sudo_mode=? WHERE id=?", (encrypted, sudo_mode, provider_id))


def sudo_status(provider: dict) -> dict:
    """Privilege summary for the UI. The sudo password itself is never returned."""
    return {
        "username": provider["username"],
        "sudo_mode": provider["sudo_mode"],
        "sudo_password_configured": bool((provider.get("credentials") or {}).get("sudo_password")),
    }


def sudo_password_configured(provider_id: str) -> bool:
    with _connect() as connection:
        row = connection.execute("SELECT credentials FROM providers WHERE id=?", (provider_id,)).fetchone()
    if not row:
        return False
    return bool(json.loads(_cipher().decrypt(row["credentials"]).decode()).get("sudo_password"))


def delete_database_credentials(provider_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM provider_database_credentials WHERE provider_id=?", (provider_id,))
    return cursor.rowcount > 0


def list_provider_host_keys(provider_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT id,fingerprint,hostname,address,approved_at,last_seen_at FROM provider_host_keys WHERE provider_id=? ORDER BY approved_at DESC",
            (provider_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def is_provider_host_key_trusted(provider_id: str, fingerprint: str) -> bool:
    with _connect() as connection:
        row = connection.execute(
            "SELECT 1 FROM provider_host_keys WHERE provider_id=? AND fingerprint=?", (provider_id, fingerprint),
        ).fetchone()
    return row is not None


def trust_provider_host_key(provider_id: str, fingerprint: str, hostname: str = "", address: str = "") -> dict:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("""INSERT INTO provider_host_keys
            (id,provider_id,fingerprint,hostname,address,approved_at,last_seen_at) VALUES (?,?,?,?,?,?,?)
            ON CONFLICT(provider_id,fingerprint) DO UPDATE SET
            hostname=CASE WHEN excluded.hostname!='' THEN excluded.hostname ELSE provider_host_keys.hostname END,
            address=CASE WHEN excluded.address!='' THEN excluded.address ELSE provider_host_keys.address END,
            last_seen_at=excluded.last_seen_at""",
            (str(uuid.uuid4()), provider_id, fingerprint, hostname, address, now, now),
        )
        connection.execute(
            "INSERT INTO host_key_events VALUES (?,?,?,?,?,?,?)",
            (str(uuid.uuid4()), provider_id, fingerprint, "approved", hostname, address, now),
        )
    return next(item for item in list_provider_host_keys(provider_id) if item["fingerprint"] == fingerprint)


def mark_provider_host_key_seen(provider_id: str, fingerprint: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute(
            "UPDATE provider_host_keys SET last_seen_at=? WHERE provider_id=? AND fingerprint=?",
            (now, provider_id, fingerprint),
        )


def list_host_key_events(provider_id: str, limit: int = 20) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT fingerprint,action,hostname,address,created_at FROM host_key_events WHERE provider_id=? ORDER BY created_at DESC LIMIT ?",
            (provider_id, limit),
        ).fetchall()
    return [dict(row) for row in rows]


def delete_provider_host_key(provider_id: str, key_id: str) -> bool:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        count = connection.execute("SELECT count(*) FROM provider_host_keys WHERE provider_id=?", (provider_id,)).fetchone()[0]
        row = connection.execute(
            "SELECT fingerprint,hostname,address FROM provider_host_keys WHERE provider_id=? AND id=?", (provider_id, key_id),
        ).fetchone()
        if not row:
            return False
        if count <= 1:
            raise ValueError("마지막 신뢰 지문은 삭제할 수 없습니다.")
        connection.execute("DELETE FROM provider_host_keys WHERE provider_id=? AND id=?", (provider_id, key_id))
        connection.execute(
            "INSERT INTO host_key_events VALUES (?,?,?,?,?,?,?)",
            (str(uuid.uuid4()), provider_id, row["fingerprint"], "removed", row["hostname"], row["address"], now),
        )
    return True


def summarize_check(status: str, result: dict) -> dict:
    """Compact, list-friendly summary of a stored check result (no raw outputs)."""
    items = result.get("items") or {}
    item_status = {key: (value or {}).get("status", "unavailable") for key, value in items.items()}
    counts = {"total": len(item_status), "healthy": 0, "warning": 0, "unavailable": 0, "excepted": 0, "skipped": 0}
    for value in item_status.values():
        counts[value if value in counts else "unavailable"] += 1
    node_summary = result.get("node_summary") or []
    node_status = {node["hostname"]: node.get("status", "healthy") for node in node_summary}
    node_items = {node["hostname"]: {"problem": list(node.get("problem_items") or []), "review": list(node.get("review_items") or [])} for node in node_summary}
    nodes = result.get("nodes") or []
    node_counts = {
        "total": len(nodes) or len(node_summary), "problem": sum(1 for v in node_status.values() if v == "problem"),
        "review": sum(1 for v in node_status.values() if v == "review"), "healthy": sum(1 for v in node_status.values() if v == "healthy"),
        "unreachable": sum(1 for node in nodes if not node.get("reachable", True)),
    }
    return {
        "status": status, "items": counts, "nodes": node_counts, "item_status": item_status, "node_status": node_status, "node_items": node_items,
        "selected_count": len(result.get("selected_items") or item_status), "started_at": result.get("started_at"),
        "finished_at": result.get("finished_at"), "duration_seconds": result.get("duration_seconds"), "trigger": result.get("trigger", "manual"),
    }


def save_check(provider_id: str, status: str, result: dict) -> str:
    check_id = str(uuid.uuid4())
    checked_at = datetime.now(timezone.utc).isoformat()
    summary = summarize_check(status, result)
    with _connect() as connection:
        connection.execute("INSERT INTO check_results (id,provider_id,status,result,checked_at,summary) VALUES (?,?,?,?,?,?)",
                           (check_id, provider_id, status, json.dumps(result), checked_at, json.dumps(summary)))
    return check_id


def latest_check(provider_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT id,status,result,checked_at FROM check_results WHERE provider_id=? ORDER BY checked_at DESC LIMIT 1", (provider_id,)).fetchone()
    return {**dict(row), "result": json.loads(row["result"])} if row else None


def get_check(provider_id: str, check_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT id,status,result,checked_at,compacted_at FROM check_results WHERE provider_id=? AND id=?", (provider_id, check_id)).fetchone()
    return {**dict(row), "result": json.loads(row["result"])} if row else None


def _check_summary_row(connection: sqlite3.Connection, row: sqlite3.Row) -> dict:
    """Return the stored summary, backfilling it once for results saved before summaries existed."""
    if row["summary"]:
        summary = json.loads(row["summary"])
    else:
        full = connection.execute("SELECT result FROM check_results WHERE id=?", (row["id"],)).fetchone()
        summary = summarize_check(row["status"], json.loads(full["result"]))
        connection.execute("UPDATE check_results SET summary=? WHERE id=?", (json.dumps(summary), row["id"]))
    return {"id": row["id"], "status": row["status"], "checked_at": row["checked_at"], "summary": summary}


def list_checks(provider_id: str, limit: int = 30) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT id,status,checked_at,summary FROM check_results WHERE provider_id=? ORDER BY checked_at DESC LIMIT ?", (provider_id, limit)).fetchall()
        return [_check_summary_row(connection, row) for row in rows]


def check_summary(provider_id: str, check_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT id,status,checked_at,summary FROM check_results WHERE provider_id=? AND id=?", (provider_id, check_id)).fetchone()
        return _check_summary_row(connection, row) if row else None


def previous_check_summary(provider_id: str, checked_at: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT id,status,checked_at,summary FROM check_results WHERE provider_id=? AND checked_at<? ORDER BY checked_at DESC LIMIT 1", (provider_id, checked_at)).fetchone()
        return _check_summary_row(connection, row) if row else None


def get_check_schedule(provider_id: str) -> dict:
    with _connect() as connection:
        row = connection.execute("SELECT * FROM check_schedules WHERE provider_id=?", (provider_id,)).fetchone()
    if not row:
        return {"provider_id": provider_id, "enabled": False, "run_time": "09:00", "selected_items": None, "last_run_at": None, "last_status": None, "last_check_id": None, "last_error": None, "updated_at": None}
    data = dict(row)
    data["enabled"] = bool(data["enabled"])
    data["selected_items"] = json.loads(data["selected_items"]) if data["selected_items"] else None
    return data


def save_check_schedule(provider_id: str, enabled: bool, run_time: str, selected_items: list[str] | None) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("""INSERT INTO check_schedules (provider_id,enabled,run_time,selected_items,updated_at) VALUES (?,?,?,?,?)
            ON CONFLICT(provider_id) DO UPDATE SET enabled=excluded.enabled, run_time=excluded.run_time, selected_items=excluded.selected_items, updated_at=excluded.updated_at""",
            (provider_id, int(enabled), run_time, json.dumps(sorted(selected_items)) if selected_items is not None else None, now))
    return get_check_schedule(provider_id)


def list_enabled_check_schedules() -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT provider_id FROM check_schedules WHERE enabled=1").fetchall()
    return [get_check_schedule(row["provider_id"]) for row in rows]


def record_schedule_run(provider_id: str, status: str, check_id: str | None, error: str | None) -> None:
    with _connect() as connection:
        connection.execute("UPDATE check_schedules SET last_run_at=?, last_status=?, last_check_id=?, last_error=? WHERE provider_id=?",
                           (datetime.now(timezone.utc).isoformat(), status, check_id, error, provider_id))


def save_provider_nodes(provider_id: str, nodes: list[dict]) -> None:
    """Replace the discovered nodes; manually added nodes and per-node maintenance flags/notes survive a re-discovery."""
    discovered_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        kept = {row["hostname"]: dict(row) for row in connection.execute("SELECT hostname,role,address,source,maintenance,note FROM provider_nodes WHERE provider_id=?", (provider_id,)).fetchall()}
        connection.execute("DELETE FROM provider_nodes WHERE provider_id=? AND source!='manual'", (provider_id,))
        for node in nodes:
            previous = kept.get(node["hostname"])
            if previous and previous["source"] == "manual":
                connection.execute("UPDATE provider_nodes SET role=?, address=?, discovered_at=? WHERE provider_id=? AND hostname=?",
                                   (node["role"], node.get("address", node["hostname"]), discovered_at, provider_id, node["hostname"]))
                continue
            connection.execute(
                "INSERT INTO provider_nodes (provider_id,hostname,role,address,source,discovered_at,maintenance,note) VALUES (?,?,?,?,?,?,?,?)",
                (provider_id, node["hostname"], node["role"], node.get("address", node["hostname"]), node["source"], discovered_at,
                 int(previous["maintenance"]) if previous else 0, previous["note"] if previous else ""),
            )


def list_provider_nodes(provider_id: str, include_maintenance: bool = True) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT hostname,role,address,source,discovered_at,maintenance,note FROM provider_nodes WHERE provider_id=? ORDER BY CASE role WHEN 'controller' THEN 0 ELSE 1 END, hostname",
            (provider_id,),
        ).fetchall()
    nodes = [{**dict(row), "maintenance": bool(row["maintenance"])} for row in rows]
    return nodes if include_maintenance else [node for node in nodes if not node["maintenance"]]


def upsert_provider_node(provider_id: str, hostname: str, role: str, address: str, note: str = "") -> dict:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute(
            "INSERT INTO provider_nodes (provider_id,hostname,role,address,source,discovered_at,maintenance,note) VALUES (?,?,?,?,'manual',?,0,?) "
            "ON CONFLICT(provider_id,hostname) DO UPDATE SET role=excluded.role, address=excluded.address, note=excluded.note, source='manual', discovered_at=excluded.discovered_at",
            (provider_id, hostname, role, address, now, note))
    return next(node for node in list_provider_nodes(provider_id) if node["hostname"] == hostname)


def update_provider_node(provider_id: str, hostname: str, changes: dict) -> dict | None:
    allowed = {"role", "address", "maintenance", "note"}
    fields = {key: value for key, value in changes.items() if key in allowed}
    if not fields:
        return next((node for node in list_provider_nodes(provider_id) if node["hostname"] == hostname), None)
    if "maintenance" in fields:
        fields["maintenance"] = 1 if fields["maintenance"] else 0
    assignments = ", ".join(f"{key}=?" for key in fields)
    with _connect() as connection:
        cursor = connection.execute(f"UPDATE provider_nodes SET {assignments} WHERE provider_id=? AND hostname=?", (*fields.values(), provider_id, hostname))
    if cursor.rowcount == 0:
        return None
    return next((node for node in list_provider_nodes(provider_id) if node["hostname"] == hostname), None)


def delete_provider_node(provider_id: str, hostname: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM provider_nodes WHERE provider_id=? AND hostname=?", (provider_id, hostname))
    return cursor.rowcount > 0


def update_provider(provider_id: str, data: dict, credentials: dict | None = None) -> dict | None:
    """Update the editable provider fields; credentials are re-encrypted only when a new set is given."""
    allowed = {"name", "vip", "port", "username", "auth_method", "fingerprint", "controller_hostname", "sudo_mode", "available_tools"}
    fields = {key: value for key, value in data.items() if key in allowed}
    if "available_tools" in fields:
        fields["available_tools"] = json.dumps(fields["available_tools"])
    if credentials is not None:
        fields["credentials"] = _cipher().encrypt(json.dumps(credentials).encode())
    fields["updated_at"] = datetime.now(timezone.utc).isoformat()
    assignments = ", ".join(f"{key}=?" for key in fields)
    with _connect() as connection:
        cursor = connection.execute(f"UPDATE providers SET {assignments} WHERE id=?", (*fields.values(), provider_id))
    if cursor.rowcount == 0:
        return None
    return get_provider(provider_id)


def list_check_exceptions(provider_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT id,item_key,node_hostname,reason,created_at FROM check_exceptions WHERE provider_id=? ORDER BY created_at DESC",
            (provider_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def save_check_exception(provider_id: str, item_key: str, reason: str, node_hostname: str = "") -> dict:
    exception_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute(
            "INSERT INTO check_exceptions VALUES (?,?,?,?,?,?) ON CONFLICT(provider_id,item_key,node_hostname) DO UPDATE SET reason=excluded.reason,created_at=excluded.created_at",
            (exception_id, provider_id, item_key, node_hostname, reason, created_at),
        )
    return next(item for item in list_check_exceptions(provider_id) if item["item_key"] == item_key and item["node_hostname"] == node_hostname)


def delete_check_exception(provider_id: str, exception_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM check_exceptions WHERE provider_id=? AND id=?", (provider_id, exception_id))
    return cursor.rowcount > 0


def list_log_exclusions(provider_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT id,service,pattern,reason,created_at FROM log_exclusions WHERE provider_id=? ORDER BY service,created_at DESC",
            (provider_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def save_log_exclusion(provider_id: str, service: str, pattern: str, reason: str) -> dict:
    exclusion_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute(
            "INSERT INTO log_exclusions VALUES (?,?,?,?,?,?) ON CONFLICT(provider_id,service,pattern) DO UPDATE SET reason=excluded.reason,created_at=excluded.created_at",
            (exclusion_id, provider_id, service, pattern, reason, created_at),
        )
    return next(item for item in list_log_exclusions(provider_id) if item["service"] == service and item["pattern"] == pattern)


def delete_log_exclusion(provider_id: str, exclusion_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM log_exclusions WHERE provider_id=? AND id=?", (provider_id, exclusion_id))
    return cursor.rowcount > 0


COMPACTED_NOTE = "보관 정책에 따라 원본 출력이 정리되었습니다. 상태·판정 결과만 보관됩니다."


def compact_check_result(result: dict) -> dict:
    """Drop raw command outputs and log samples from a stored result while keeping every status and verdict."""
    for node in result.get("nodes") or []:
        metrics = node.get("metrics") or {}
        for key in list(metrics):
            if key.endswith(("_raw", "_log_sample", "_previous_log_sample", "_summary")):
                metrics.pop(key, None)
    for item in (result.get("items") or {}).values():
        if not isinstance(item, dict):
            continue
        if item.get("details"):
            item["details"] = [{"title": "원본 출력 정리됨", "output": COMPACTED_NOTE}]
        for entry in item.get("nodes") or []:
            if isinstance(entry, dict):
                for key in ("output", "new_output"):
                    if entry.get(key):
                        entry[key] = ""
                entry["compacted"] = True
        item["compacted"] = True
    result["compacted"] = True
    return result


def check_storage_stats() -> dict:
    with _connect() as connection:
        rows = connection.execute("""SELECT p.id AS provider_id, p.name AS provider_name, COUNT(c.id) AS count,
                COALESCE(SUM(length(c.result)),0) AS bytes, MIN(c.checked_at) AS oldest, MAX(c.checked_at) AS newest,
                SUM(CASE WHEN c.compacted_at IS NULL THEN 0 ELSE 1 END) AS compacted
            FROM providers p LEFT JOIN check_results c ON c.provider_id=p.id GROUP BY p.id ORDER BY p.name""").fetchall()
        total = connection.execute("SELECT COUNT(*) AS count, COALESCE(SUM(length(result)),0) AS bytes FROM check_results").fetchone()
        run = connection.execute("SELECT ran_at,detail FROM maintenance_runs WHERE name='prune'").fetchone()
    try:
        db_bytes = DB_FILE.stat().st_size
    except OSError:
        db_bytes = 0
    return {
        "providers": [dict(row) for row in rows], "total_count": total["count"], "total_bytes": total["bytes"], "db_bytes": db_bytes,
        "last_prune": {"ran_at": run["ran_at"], **json.loads(run["detail"])} if run else None,
    }


def prune_check_results(max_age_days: int, raw_age_days: int, max_per_provider: int, keep_latest: int) -> dict:
    """Apply the retention policy: delete old or excess results, compact raw outputs of ageing ones, keep the newest untouched."""
    now = datetime.now(timezone.utc)
    delete_before = (now - timedelta(days=max_age_days)).isoformat() if max_age_days > 0 else None
    compact_before = (now - timedelta(days=raw_age_days)).isoformat() if raw_age_days > 0 else None
    deleted = compacted = 0
    freed = 0
    with _connect() as connection:
        providers = [row["id"] for row in connection.execute("SELECT id FROM providers")]
        providers.append(None)  # results whose provider was removed
        for provider_id in providers:
            if provider_id is None:
                rows = connection.execute("SELECT id,checked_at,compacted_at,length(result) AS bytes FROM check_results WHERE provider_id NOT IN (SELECT id FROM providers) ORDER BY checked_at DESC").fetchall()
            else:
                rows = connection.execute("SELECT id,checked_at,compacted_at,length(result) AS bytes FROM check_results WHERE provider_id=? ORDER BY checked_at DESC", (provider_id,)).fetchall()
            for index, row in enumerate(rows):
                if provider_id is not None and index < keep_latest:
                    continue
                expired = delete_before is not None and row["checked_at"] < delete_before
                excess = max_per_provider > 0 and index >= max_per_provider
                if provider_id is None or expired or excess:
                    connection.execute("DELETE FROM check_results WHERE id=?", (row["id"],))
                    deleted += 1
                    freed += row["bytes"]
                    continue
                if compact_before is not None and row["checked_at"] < compact_before and not row["compacted_at"]:
                    full = connection.execute("SELECT result FROM check_results WHERE id=?", (row["id"],)).fetchone()
                    compacted_result = json.dumps(compact_check_result(json.loads(full["result"])))
                    connection.execute("UPDATE check_results SET result=?, compacted_at=? WHERE id=?", (compacted_result, now.isoformat(), row["id"]))
                    compacted += 1
                    freed += max(row["bytes"] - len(compacted_result), 0)
        detail = {"deleted": deleted, "compacted": compacted, "freed_bytes": freed,
                  "policy": {"max_age_days": max_age_days, "raw_age_days": raw_age_days, "max_per_provider": max_per_provider, "keep_latest": keep_latest}}
        connection.execute("INSERT INTO maintenance_runs VALUES ('prune',?,?) ON CONFLICT(name) DO UPDATE SET ran_at=excluded.ran_at, detail=excluded.detail", (now.isoformat(), json.dumps(detail)))
    if deleted or compacted:
        with sqlite3.connect(DB_FILE) as connection:
            connection.execute("VACUUM")
    return {"ran_at": now.isoformat(), **detail}


def list_custom_checks(provider_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT * FROM custom_checks WHERE provider_id=? ORDER BY created_at", (provider_id,)).fetchall()
    return [{**dict(row), "enabled": bool(row["enabled"]), "key": f"custom:{row['id']}"} for row in rows]


def save_custom_check(provider_id: str, data: dict, check_id: str | None = None) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    check_id = check_id or str(uuid.uuid4())
    with _connect() as connection:
        connection.execute("""INSERT INTO custom_checks
            (id,provider_id,name,description,target_role,command,execution_context,rule_type,expected_value,timeout_seconds,enabled,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,
            target_role=excluded.target_role,command=excluded.command,execution_context=excluded.execution_context,rule_type=excluded.rule_type,
            expected_value=excluded.expected_value,timeout_seconds=excluded.timeout_seconds,
            enabled=excluded.enabled,updated_at=excluded.updated_at""", (
                check_id, provider_id, data["name"], data.get("description", ""), data["target_role"],
                data["command"], data.get("execution_context", "plain"), data["rule_type"], data.get("expected_value", ""),
                data["timeout_seconds"], int(data.get("enabled", True)), now, now,
            ))
    return next(item for item in list_custom_checks(provider_id) if item["id"] == check_id)


def delete_custom_check(provider_id: str, check_id: str) -> bool:
    with _connect() as connection:
        connection.execute("DELETE FROM check_exceptions WHERE provider_id=? AND item_key=?", (provider_id, f"custom:{check_id}"))
        cursor = connection.execute("DELETE FROM custom_checks WHERE provider_id=? AND id=?", (provider_id, check_id))
    return cursor.rowcount > 0


def save_work_history(data: dict) -> dict:
    history_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("""INSERT INTO work_histories
            (id,provider_id,title,work_type,status,operator,target,ticket,description,commands,
             before_state,after_state,result,follow_up,started_at,completed_at,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", (
            history_id, data.get("provider_id") or None, data["title"], data["work_type"], data["status"],
            data["operator"], data.get("target", ""), data.get("ticket", ""), data["description"],
            data.get("commands", ""), data.get("before_state", ""), data.get("after_state", ""),
            data.get("result", ""), data.get("follow_up", ""), data["started_at"],
            data.get("completed_at") or None, now, now,
        ))
    return get_work_history(history_id)


def get_work_history(history_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("""SELECT w.*, p.name AS provider_name
            FROM work_histories w LEFT JOIN providers p ON p.id=w.provider_id WHERE w.id=?""", (history_id,)).fetchone()
    return dict(row) if row else None


def list_work_histories(provider_id: str = "", work_type: str = "", status: str = "", query: str = "", limit: int = 200) -> list[dict]:
    clauses, values = [], []
    if provider_id:
        clauses.append("w.provider_id=?"); values.append(provider_id)
    if work_type:
        clauses.append("w.work_type=?"); values.append(work_type)
    if status:
        clauses.append("w.status=?"); values.append(status)
    if query:
        clauses.append("(w.title LIKE ? OR w.target LIKE ? OR w.operator LIKE ? OR w.ticket LIKE ? OR w.description LIKE ?)")
        values.extend([f"%{query}%"] * 5)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    values.append(max(1, min(limit, 500)))
    with _connect() as connection:
        rows = connection.execute(f"""SELECT w.*, p.name AS provider_name
            FROM work_histories w LEFT JOIN providers p ON p.id=w.provider_id
            {where} ORDER BY w.started_at DESC, w.created_at DESC LIMIT ?""", values).fetchall()
    return [dict(row) for row in rows]


def update_work_history(history_id: str, data: dict) -> dict | None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        cursor = connection.execute("""UPDATE work_histories SET
            provider_id=?,title=?,work_type=?,status=?,operator=?,target=?,ticket=?,description=?,commands=?,
            before_state=?,after_state=?,result=?,follow_up=?,started_at=?,completed_at=?,updated_at=? WHERE id=?""", (
            data.get("provider_id") or None, data["title"], data["work_type"], data["status"], data["operator"],
            data.get("target", ""), data.get("ticket", ""), data["description"], data.get("commands", ""),
            data.get("before_state", ""), data.get("after_state", ""), data.get("result", ""), data.get("follow_up", ""),
            data["started_at"], data.get("completed_at") or None, now, history_id,
        ))
    return get_work_history(history_id) if cursor.rowcount else None


def delete_work_history(history_id: str) -> bool:
    with _connect() as connection:
        connection.execute("UPDATE alerts SET work_history_id=NULL WHERE work_history_id=?", (history_id,))
        connection.execute("DELETE FROM work_history_attachments WHERE history_id=?", (history_id,))
        cursor = connection.execute("DELETE FROM work_histories WHERE id=?", (history_id,))
    if cursor.rowcount:
        shutil.rmtree(attachment_dir(history_id), ignore_errors=True)
    return cursor.rowcount > 0


def sync_check_alerts(provider_id: str, check_id: str, items: dict) -> None:
    now = datetime.now(timezone.utc).isoformat()
    active_keys = set()
    with _connect() as connection:
        windows = _active_maintenance_windows(connection, provider_id, now)
        for key, item in items.items():
            state = item.get("status")
            if state not in {"warning", "unavailable"}:
                continue
            source_key = f"inspection:{key}"
            active_keys.add(source_key)
            severity = "critical" if state == "unavailable" else "warning"
            title = item.get("name") or key.replace("_", " ").title()
            description = item.get("note") or item.get("result") or "일일점검에서 이상 상태를 감지했습니다."
            failing_nodes = [detail.get("hostname", "") for detail in item.get("nodes", []) if detail.get("status") in {"warning", "unavailable"}]
            target = ", ".join(failing_nodes)
            suppressed_until = _maintenance_suppression(windows, failing_nodes, key)
            row = connection.execute("""SELECT id,status,suppressed_until FROM alerts
                WHERE provider_id=? AND source_key=? ORDER BY last_detected_at DESC LIMIT 1""", (provider_id, source_key)).fetchone()
            if row and row["status"] != "resolved":
                connection.execute("""UPDATE alerts SET check_id=?,severity=?,title=?,description=?,target=?,
                    last_detected_at=?,suppressed_until=? WHERE id=?""", (check_id, severity, title, description, target, now, suppressed_until, row["id"]))
                was_suppressed = bool(row["suppressed_until"]) and row["suppressed_until"] > now
                if suppressed_until and not was_suppressed:
                    _record_alert_event(connection, row["id"], "suppressed", f"정비 시간 창에 포함되어 {suppressed_until[:16].replace('T', ' ')} UTC까지 알림을 억제합니다.", "system")
                else:
                    _record_alert_event(connection, row["id"], "redetected", f"일일점검에서 다시 감지됨 · {description}"[:500], "system")
            else:
                alert_id = str(uuid.uuid4())
                connection.execute("""INSERT INTO alerts
                    (id,provider_id,check_id,source_key,category,severity,status,title,description,target,assignee,
                     work_history_id,first_detected_at,last_detected_at,acknowledged_at,resolved_at,resolution_note,suppressed_until)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", (
                    alert_id, provider_id, check_id, source_key, "inspection", severity, "open", title,
                    description, target, "", None, now, now, None, None, "", suppressed_until,
                ))
                _record_alert_event(connection, alert_id, "detected", f"일일점검에서 감지됨 · {description}"[:500], "system")
                if suppressed_until:
                    _record_alert_event(connection, alert_id, "suppressed", f"정비 시간 창에 포함되어 {suppressed_until[:16].replace('T', ' ')} UTC까지 알림을 억제합니다.", "system")
        # Only items that were actually checked this run can clear an alert; a partial run must not resolve the rest.
        checked_keys = {f"inspection:{key}" for key in items}
        open_rows = connection.execute("""SELECT id,source_key FROM alerts
            WHERE provider_id=? AND category='inspection' AND status!='resolved'""", (provider_id,)).fetchall()
        for row in open_rows:
            if row["source_key"] in checked_keys and row["source_key"] not in active_keys:
                connection.execute("UPDATE alerts SET status='resolved',resolved_at=?,resolution_note=?,suppressed_until=NULL WHERE id=?",
                                   (now, "후속 일일점검에서 정상 상태를 확인하여 자동 해소", row["id"]))
                _record_alert_event(connection, row["id"], "auto_resolved", "후속 일일점검에서 정상 상태를 확인하여 자동 해소", "system")


def list_alerts(provider_id: str = "", status: str = "", severity: str = "", query: str = "", limit: int = 300) -> list[dict]:
    clauses, values = [], []
    now = datetime.now(timezone.utc).isoformat()
    if provider_id: clauses.append("a.provider_id=?"); values.append(provider_id)
    if status == "suppressed":
        clauses.append("a.status!='resolved' AND a.suppressed_until IS NOT NULL AND a.suppressed_until>?"); values.append(now)
    elif status in {"open", "acknowledged"}:
        # Suppressed alerts are hidden from the working queues; they are listed under their own filter.
        clauses.append("a.status=? AND (a.suppressed_until IS NULL OR a.suppressed_until<=?)"); values.extend([status, now])
    elif status:
        clauses.append("a.status=?"); values.append(status)
    if severity: clauses.append("a.severity=?"); values.append(severity)
    if query:
        clauses.append("(a.title LIKE ? OR a.description LIKE ? OR a.target LIKE ? OR a.assignee LIKE ?)")
        values.extend([f"%{query}%"] * 4)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    values.append(max(1, min(limit, 500)))
    with _connect() as connection:
        rows = connection.execute(f"""SELECT a.*,p.name AS provider_name,w.title AS work_history_title
            FROM alerts a LEFT JOIN providers p ON p.id=a.provider_id
            LEFT JOIN work_histories w ON w.id=a.work_history_id {where}
            ORDER BY CASE a.status WHEN 'open' THEN 0 WHEN 'acknowledged' THEN 1 ELSE 2 END,
            CASE a.severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,a.last_detected_at DESC LIMIT ?""", values).fetchall()
    return [_decorate_alert(dict(row), now) for row in rows]


def get_alert(alert_id: str) -> dict | None:
    return next(iter(list_alerts_by_id(alert_id)), None)


def list_alerts_by_id(alert_id: str) -> list[dict]:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        rows = connection.execute("""SELECT a.*,p.name AS provider_name,w.title AS work_history_title
            FROM alerts a LEFT JOIN providers p ON p.id=a.provider_id
            LEFT JOIN work_histories w ON w.id=a.work_history_id WHERE a.id=?""", (alert_id,)).fetchall()
    return [_decorate_alert(dict(row), now) for row in rows]


def update_alert(alert_id: str, status: str, assignee: str, resolution_note: str, work_history_id: str | None, actor: str = "") -> dict | None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        before = connection.execute("SELECT status,assignee,work_history_id FROM alerts WHERE id=?", (alert_id,)).fetchone()
        cursor = connection.execute("""UPDATE alerts SET status=?,assignee=?,resolution_note=?,work_history_id=?,
            acknowledged_at=CASE WHEN ?='acknowledged' AND acknowledged_at IS NULL THEN ? ELSE acknowledged_at END,
            resolved_at=CASE WHEN ?='resolved' THEN ? WHEN ?!='resolved' THEN NULL ELSE resolved_at END WHERE id=?""",
            (status, assignee, resolution_note, work_history_id, status, now, status, now, status, alert_id))
        if cursor.rowcount and before:
            if before["status"] != status:
                kind = {"acknowledged": "acknowledged", "resolved": "resolved"}.get(status, "reopened")
                text = {"acknowledged": "확인 처리", "resolved": f"해소 처리 · {resolution_note}".rstrip(" ·"), "open": "미확인 상태로 되돌림"}.get(status, status)
                _record_alert_event(connection, alert_id, kind, text[:500], actor)
            if (before["assignee"] or "") != (assignee or ""):
                _record_alert_event(connection, alert_id, "assigned", f"담당자 {assignee or '지정 해제'}", actor)
            if (before["work_history_id"] or None) != (work_history_id or None) and work_history_id:
                _record_alert_event(connection, alert_id, "note", f"작업 이력 연결 {work_history_id}", actor)
    return get_alert(alert_id) if cursor.rowcount else None


def alert_summary() -> dict:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        rows = connection.execute("""SELECT status,severity,count(*) count,
            SUM(CASE WHEN suppressed_until IS NOT NULL AND suppressed_until>? THEN 1 ELSE 0 END) suppressed
            FROM alerts GROUP BY status,severity""", (now,)).fetchall()
    live = [row for row in rows if row["status"] != "resolved"]
    active = sum(row["count"] - (row["suppressed"] or 0) for row in live)
    suppressed = sum(row["suppressed"] or 0 for row in live)
    return {"active": active, "suppressed": suppressed,
            "critical": sum(row["count"] - (row["suppressed"] or 0) for row in live if row["severity"] == "critical"),
            "groups": [{"status": row["status"], "severity": row["severity"], "count": row["count"] - (row["suppressed"] or 0 if row["status"] != "resolved" else 0)} for row in rows]}


def delete_provider(provider_id: str) -> bool:
    with _connect() as connection:
        exists = connection.execute("SELECT 1 FROM providers WHERE id=?", (provider_id,)).fetchone()
        if not exists:
            return False
        connection.execute("DELETE FROM check_results WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM provider_nodes WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM check_exceptions WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM custom_checks WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM provider_host_keys WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM host_key_events WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM provider_database_credentials WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM check_schedules WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM log_exclusions WHERE provider_id=?", (provider_id,))
        _ensure_inventory_table(connection)
        connection.execute("DELETE FROM provider_inventory WHERE provider_id=?", (provider_id,))
        connection.execute("UPDATE work_histories SET provider_id=NULL WHERE provider_id=?", (provider_id,))
        connection.execute("UPDATE alerts SET provider_id=NULL WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM app_settings WHERE key LIKE ?", (f"provider:{provider_id}:%",))
        connection.execute("DELETE FROM providers WHERE id=?", (provider_id,))
    return True


# --- Platform settings (server-side, JSON values) ----------------------------------------------

def get_setting(key: str, default=None):
    with _connect() as connection:
        row = connection.execute("SELECT value FROM app_settings WHERE key=?", (key,)).fetchone()
    if not row:
        return default
    try:
        return json.loads(row["value"])
    except (TypeError, ValueError):
        return default


def get_setting_info(key: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT key, value, updated_at, updated_by FROM app_settings WHERE key=?", (key,)).fetchone()
    if not row:
        return None
    try:
        value = json.loads(row["value"])
    except (TypeError, ValueError):
        value = None
    return {"key": row["key"], "value": value, "updated_at": row["updated_at"], "updated_by": row["updated_by"]}


def list_settings(prefix: str = "") -> dict[str, dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT key, value, updated_at, updated_by FROM app_settings WHERE key LIKE ? ORDER BY key", (f"{prefix}%",)).fetchall()
    result = {}
    for row in rows:
        try:
            value = json.loads(row["value"])
        except (TypeError, ValueError):
            continue
        result[row["key"]] = {"value": value, "updated_at": row["updated_at"], "updated_by": row["updated_by"]}
    return result


def set_setting(key: str, value, updated_by: str = "") -> dict:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute(
            "INSERT INTO app_settings (key, value, updated_at, updated_by) VALUES (?, ?, ?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at, updated_by=excluded.updated_by",
            (key, json.dumps(value, ensure_ascii=False), now, updated_by))
    return {"key": key, "value": value, "updated_at": now, "updated_by": updated_by}


def delete_setting(key: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM app_settings WHERE key=?", (key,))
    return cursor.rowcount > 0


# --- Audit log -----------------------------------------------------------------------------------

def record_audit(actor: str, action: str, target_type: str = "", target_id: str = "", target_name: str = "", detail: str = "",
                 outcome: str = "success", remote_addr: str = "", user_agent: str = "") -> int:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        cursor = connection.execute(
            "INSERT INTO audit_logs (created_at, actor, action, target_type, target_id, target_name, detail, outcome, remote_addr, user_agent) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (now, (actor or "")[:100], action[:80], (target_type or "")[:40], (target_id or "")[:120], (target_name or "")[:200],
             (detail or "")[:2000], (outcome or "success")[:20], (remote_addr or "")[:64], (user_agent or "")[:300]))
        return int(cursor.lastrowid)


def list_audit_logs(limit: int = 50, offset: int = 0, actor: str = "", action: str = "", target_type: str = "", target_id: str = "",
                    outcome: str = "", search: str = "", since: str = "", until: str = "") -> dict:
    clauses, params = [], []
    if actor:
        clauses.append("actor=?"); params.append(actor)
    if action:
        if action.endswith("."):
            clauses.append("action LIKE ?"); params.append(f"{action}%")
        else:
            clauses.append("action=?"); params.append(action)
    if target_type:
        clauses.append("target_type=?"); params.append(target_type)
    if target_id:
        clauses.append("target_id=?"); params.append(target_id)
    if outcome:
        clauses.append("outcome=?"); params.append(outcome)
    if since:
        clauses.append("created_at>=?"); params.append(since)
    if until:
        clauses.append("created_at<=?"); params.append(until)
    if search:
        like = f"%{search}%"
        clauses.append("(target_name LIKE ? OR detail LIKE ? OR actor LIKE ? OR action LIKE ? OR target_id LIKE ?)")
        params.extend([like, like, like, like, like])
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    with _connect() as connection:
        total = connection.execute(f"SELECT COUNT(*) FROM audit_logs {where}", params).fetchone()[0]
        rows = connection.execute(f"SELECT * FROM audit_logs {where} ORDER BY id DESC LIMIT ? OFFSET ?", (*params, limit, offset)).fetchall()
    return {"items": [dict(row) for row in rows], "total": total, "limit": limit, "offset": offset}


def audit_log_facets(days: int = 30) -> dict:
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    with _connect() as connection:
        actions = connection.execute("SELECT action, COUNT(*) AS count FROM audit_logs WHERE created_at>=? GROUP BY action ORDER BY count DESC", (since,)).fetchall()
        actors = connection.execute("SELECT actor, COUNT(*) AS count FROM audit_logs WHERE created_at>=? GROUP BY actor ORDER BY count DESC", (since,)).fetchall()
        outcomes = connection.execute("SELECT outcome, COUNT(*) AS count FROM audit_logs WHERE created_at>=? GROUP BY outcome", (since,)).fetchall()
        total = connection.execute("SELECT COUNT(*) FROM audit_logs").fetchone()[0]
        oldest = connection.execute("SELECT MIN(created_at) FROM audit_logs").fetchone()[0]
    return {"days": days, "actions": [dict(row) for row in actions], "actors": [dict(row) for row in actors],
            "outcomes": [dict(row) for row in outcomes], "total": total, "oldest": oldest}


def prune_audit_logs(max_age_days: int) -> int:
    if not max_age_days:
        return 0
    cutoff = (datetime.now(timezone.utc) - timedelta(days=max_age_days)).isoformat()
    with _connect() as connection:
        cursor = connection.execute("DELETE FROM audit_logs WHERE created_at<?", (cutoff,))
    return cursor.rowcount


# --- Work history extensions -------------------------------------------------------------------

WORK_TRANSITIONS = {
    "planned": {"approved", "in_progress", "failed"},
    "approved": {"in_progress", "planned", "failed"},
    "in_progress": {"completed", "failed"},
    "completed": {"in_progress"},
    "failed": {"in_progress", "planned"},
}


def transition_work_history(history_id: str, status: str, actor: str) -> dict | None:
    """Move a work history along 예정 → 승인 → 진행 중 → 완료/실패; returns None when the history is missing."""
    current = get_work_history(history_id)
    if not current:
        return None
    if status not in WORK_TRANSITIONS.get(current["status"], set()):
        raise ValueError(f"{current['status']} 상태에서는 {status} 상태로 바꿀 수 없습니다.")
    now = datetime.now(timezone.utc).isoformat()
    approved_by, approved_at = current.get("approved_by") or "", current.get("approved_at")
    if status == "approved":
        approved_by, approved_at = actor, now
    completed_at = current.get("completed_at")
    if status in {"completed", "failed"} and not completed_at:
        completed_at = now
    if status in {"planned", "approved", "in_progress"}:
        completed_at = None
    with _connect() as connection:
        connection.execute("UPDATE work_histories SET status=?, approved_by=?, approved_at=?, completed_at=?, updated_at=? WHERE id=?",
                           (status, approved_by, approved_at, completed_at, now, history_id))
    return get_work_history(history_id)


def set_work_history_check(history_id: str, phase: str, check_id: str | None) -> dict | None:
    column = "before_check_id" if phase == "before" else "after_check_id"
    with _connect() as connection:
        cursor = connection.execute(f"UPDATE work_histories SET {column}=?, updated_at=? WHERE id=?", (check_id, datetime.now(timezone.utc).isoformat(), history_id))
    return get_work_history(history_id) if cursor.rowcount else None


def list_work_histories_for_month(month: str, provider_id: str = "") -> list[dict]:
    """Histories whose started_at falls in YYYY-MM (UTC); the CSV export converts to the display time zone itself."""
    clauses, values = ["substr(w.started_at, 1, 7)=?"], [month]
    if provider_id:
        clauses.append("w.provider_id=?"); values.append(provider_id)
    with _connect() as connection:
        rows = connection.execute(f"""SELECT w.*, p.name AS provider_name FROM work_histories w LEFT JOIN providers p ON p.id=w.provider_id
            WHERE {' AND '.join(clauses)} ORDER BY w.started_at ASC""", values).fetchall()
    return [dict(row) for row in rows]


def attachment_dir(history_id: str) -> Path:
    return DATA_DIR / "attachments" / history_id


def list_work_history_attachments(history_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT id, history_id, filename, content_type, size, uploaded_by, uploaded_at FROM work_history_attachments WHERE history_id=? ORDER BY uploaded_at ASC", (history_id,)).fetchall()
    return [dict(row) for row in rows]


def add_work_history_attachment(history_id: str, filename: str, content_type: str, data: bytes, uploaded_by: str) -> dict:
    attachment_id = uuid.uuid4().hex
    suffix = Path(filename).suffix[:16]
    stored_name = f"{attachment_id}{suffix}"
    folder = attachment_dir(history_id)
    folder.mkdir(parents=True, exist_ok=True)
    (folder / stored_name).write_bytes(data)
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("INSERT INTO work_history_attachments (id, history_id, filename, content_type, size, stored_name, uploaded_by, uploaded_at) VALUES (?,?,?,?,?,?,?,?)",
                           (attachment_id, history_id, filename[:255], (content_type or "")[:120], len(data), stored_name, uploaded_by[:100], now))
    return {"id": attachment_id, "history_id": history_id, "filename": filename[:255], "content_type": content_type or "", "size": len(data), "uploaded_by": uploaded_by, "uploaded_at": now}


def get_work_history_attachment(history_id: str, attachment_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT * FROM work_history_attachments WHERE history_id=? AND id=?", (history_id, attachment_id)).fetchone()
    if not row:
        return None
    return {**dict(row), "path": attachment_dir(history_id) / row["stored_name"]}


def delete_work_history_attachment(history_id: str, attachment_id: str) -> dict | None:
    attachment = get_work_history_attachment(history_id, attachment_id)
    if not attachment:
        return None
    with _connect() as connection:
        connection.execute("DELETE FROM work_history_attachments WHERE id=?", (attachment_id,))
    try:
        attachment["path"].unlink()
    except FileNotFoundError:
        pass
    return attachment


# --- Alerts extensions ---------------------------------------------------------------------------

def _record_alert_event(connection: sqlite3.Connection, alert_id: str, kind: str, text: str = "", actor: str = "") -> None:
    connection.execute("INSERT INTO alert_events (alert_id, created_at, actor, kind, text) VALUES (?, ?, ?, ?, ?)",
                       (alert_id, datetime.now(timezone.utc).isoformat(), (actor or "")[:100], kind[:30], (text or "")[:2000]))


def _decorate_alert(alert: dict, now: str) -> dict:
    alert["suppressed"] = bool(alert.get("suppressed_until")) and alert["status"] != "resolved" and alert["suppressed_until"] > now
    alert["active"] = alert["status"] != "resolved" and not alert["suppressed"]
    return alert


def is_active_alert(alert: dict) -> bool:
    """Not resolved and not currently suppressed by a maintenance window."""
    if alert.get("status") == "resolved":
        return False
    until = alert.get("suppressed_until")
    return not (until and until > datetime.now(timezone.utc).isoformat())


def list_alert_events(alert_id: str, limit: int = 200) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("SELECT id, alert_id, created_at, actor, kind, text FROM alert_events WHERE alert_id=? ORDER BY id DESC LIMIT ?", (alert_id, limit)).fetchall()
    return [dict(row) for row in rows]


def add_alert_comment(alert_id: str, text: str, actor: str) -> dict | None:
    with _connect() as connection:
        if not connection.execute("SELECT 1 FROM alerts WHERE id=?", (alert_id,)).fetchone():
            return None
        _record_alert_event(connection, alert_id, "comment", text, actor)
        row = connection.execute("SELECT id, alert_id, created_at, actor, kind, text FROM alert_events WHERE alert_id=? ORDER BY id DESC LIMIT 1", (alert_id,)).fetchone()
    return dict(row)


def bulk_update_alerts(alert_ids: list[str], status: str, assignee: str, resolution_note: str, actor: str) -> list[dict]:
    updated = []
    for alert_id in alert_ids:
        current = get_alert(alert_id)
        if not current:
            continue
        result = update_alert(alert_id, status, assignee if assignee else current.get("assignee", ""), resolution_note or current.get("resolution_note", ""),
                              current.get("work_history_id"), actor)
        if result:
            updated.append(result)
    return updated


def _window_row(row: sqlite3.Row, now: str) -> dict:
    window = dict(row)
    window["nodes"] = json.loads(window.get("nodes") or "[]")
    window["item_keys"] = json.loads(window.get("item_keys") or "[]")
    window["state"] = "active" if window["starts_at"] <= now <= window["ends_at"] else ("upcoming" if window["starts_at"] > now else "past")
    return window


def list_maintenance_windows(provider_id: str = "", state: str = "", limit: int = 200) -> list[dict]:
    now = datetime.now(timezone.utc).isoformat()
    clauses, values = [], []
    if provider_id:
        clauses.append("(m.provider_id=? OR m.provider_id IS NULL)"); values.append(provider_id)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    with _connect() as connection:
        rows = connection.execute(f"""SELECT m.*, p.name AS provider_name, w.title AS work_history_title
            FROM maintenance_windows m LEFT JOIN providers p ON p.id=m.provider_id LEFT JOIN work_histories w ON w.id=m.work_history_id
            {where} ORDER BY m.starts_at DESC LIMIT ?""", (*values, max(1, min(limit, 500)))).fetchall()
    windows = [_window_row(row, now) for row in rows]
    if state:
        windows = [window for window in windows if window["state"] == state]
    return windows


def get_maintenance_window(window_id: str) -> dict | None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        row = connection.execute("""SELECT m.*, p.name AS provider_name, w.title AS work_history_title
            FROM maintenance_windows m LEFT JOIN providers p ON p.id=m.provider_id LEFT JOIN work_histories w ON w.id=m.work_history_id WHERE m.id=?""", (window_id,)).fetchone()
    return _window_row(row, now) if row else None


def save_maintenance_window(data: dict, created_by: str = "") -> dict:
    window_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("""INSERT INTO maintenance_windows (id, provider_id, title, starts_at, ends_at, nodes, item_keys, work_history_id, note, created_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", (
            window_id, data.get("provider_id") or None, data["title"], data["starts_at"], data["ends_at"],
            json.dumps(data.get("nodes") or []), json.dumps(data.get("item_keys") or []), data.get("work_history_id") or None,
            data.get("note") or "", created_by, now))
        # Alerts already active that fall inside the window are suppressed right away, not only at the next inspection.
        if data["starts_at"] <= now <= data["ends_at"]:
            clauses, values = ["status!='resolved'", "category='inspection'"], []
            if data.get("provider_id"):
                clauses.append("provider_id=?"); values.append(data["provider_id"])
            rows = connection.execute(f"SELECT id, source_key, target, suppressed_until FROM alerts WHERE {' AND '.join(clauses)}", values).fetchall()
            window = {**data, "nodes": data.get("nodes") or [], "item_keys": data.get("item_keys") or []}
            for row in rows:
                item_key = row["source_key"].split(":", 1)[-1]
                hosts = [part.strip() for part in (row["target"] or "").split(",") if part.strip()]
                if _window_matches(window, hosts, item_key) and (not row["suppressed_until"] or row["suppressed_until"] < data["ends_at"]):
                    connection.execute("UPDATE alerts SET suppressed_until=? WHERE id=?", (data["ends_at"], row["id"]))
                    _record_alert_event(connection, row["id"], "suppressed", f"정비 시간 창 '{data['title']}'에 포함되어 {data['ends_at'][:16].replace('T', ' ')} UTC까지 알림을 억제합니다.", created_by or "system")
    return get_maintenance_window(window_id)


def delete_maintenance_window(window_id: str, actor: str = "") -> dict | None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        row = connection.execute("SELECT * FROM maintenance_windows WHERE id=?", (window_id,)).fetchone()
        if not row:
            return None
        window = _window_row(row, now)
        connection.execute("DELETE FROM maintenance_windows WHERE id=?", (window_id,))
        if window["state"] == "active":
            # Lift the suppression this window granted unless another active window still covers the alert.
            others = [_window_row(other, now) for other in connection.execute("SELECT * FROM maintenance_windows WHERE id!=? AND starts_at<=? AND ends_at>=?", (window_id, now, now)).fetchall()]
            rows = connection.execute("SELECT id, provider_id, source_key, target FROM alerts WHERE status!='resolved' AND suppressed_until IS NOT NULL AND suppressed_until>?", (now,)).fetchall()
            for alert in rows:
                item_key = alert["source_key"].split(":", 1)[-1]
                hosts = [part.strip() for part in (alert["target"] or "").split(",") if part.strip()]
                if not _window_matches(window, hosts, item_key) or (window["provider_id"] and window["provider_id"] != alert["provider_id"]):
                    continue
                still = [other["ends_at"] for other in others if (not other["provider_id"] or other["provider_id"] == alert["provider_id"]) and _window_matches(other, hosts, item_key)]
                connection.execute("UPDATE alerts SET suppressed_until=? WHERE id=?", (max(still) if still else None, alert["id"]))
                if not still:
                    _record_alert_event(connection, alert["id"], "note", f"정비 시간 창 '{window['title']}' 삭제로 알림 억제 해제", actor or "system")
    return window


def _window_matches(window: dict, hostnames: list[str], item_key: str) -> bool:
    if window.get("item_keys") and item_key not in window["item_keys"]:
        return False
    if window.get("nodes"):
        if not hostnames:
            return False
        short = {host.split(".")[0] for host in window["nodes"]}
        return all(host.split(".")[0] in short for host in hostnames)
    return True


def _active_maintenance_windows(connection: sqlite3.Connection, provider_id: str, now: str) -> list[dict]:
    rows = connection.execute("SELECT * FROM maintenance_windows WHERE starts_at<=? AND ends_at>=? AND (provider_id IS NULL OR provider_id=?)", (now, now, provider_id)).fetchall()
    return [_window_row(row, now) for row in rows]


def _maintenance_suppression(windows: list[dict], hostnames: list[str], item_key: str) -> str | None:
    ends = [window["ends_at"] for window in windows if _window_matches(window, hostnames, item_key)]
    return max(ends) if ends else None


def active_maintenance_windows(provider_id: str) -> list[dict]:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        return _active_maintenance_windows(connection, provider_id, now)


def alert_stats(days: int = 30) -> dict:
    now_dt = datetime.now(timezone.utc)
    now = now_dt.isoformat()
    since = (now_dt - timedelta(days=days)).isoformat()
    stale_before = (now_dt - timedelta(days=3)).isoformat()

    def seconds_between(start: str | None, end: str | None) -> float | None:
        if not start or not end:
            return None
        try:
            return (datetime.fromisoformat(end) - datetime.fromisoformat(start)).total_seconds()
        except ValueError:
            return None

    with _connect() as connection:
        acknowledged = connection.execute("SELECT first_detected_at, acknowledged_at FROM alerts WHERE acknowledged_at IS NOT NULL AND acknowledged_at>=?", (since,)).fetchall()
        resolved = connection.execute("SELECT first_detected_at, resolved_at, resolution_note FROM alerts WHERE resolved_at IS NOT NULL AND resolved_at>=?", (since,)).fetchall()
        severity_rows = connection.execute("""SELECT severity, status, count(*) count,
            SUM(CASE WHEN suppressed_until IS NOT NULL AND suppressed_until>? THEN 1 ELSE 0 END) suppressed FROM alerts GROUP BY severity, status""", (now,)).fetchall()
        recurring = connection.execute("""SELECT a.source_key, a.title, p.name AS provider_name, a.provider_id, COUNT(e.id) AS repeats
            FROM alert_events e JOIN alerts a ON a.id=e.alert_id LEFT JOIN providers p ON p.id=a.provider_id
            WHERE e.created_at>=? AND e.kind IN ('redetected','reopened') GROUP BY a.provider_id, a.source_key ORDER BY repeats DESC LIMIT 8""", (since,)).fetchall()
        stale = connection.execute("""SELECT a.id, a.title, a.severity, a.status, a.first_detected_at, a.target, p.name AS provider_name FROM alerts a LEFT JOIN providers p ON p.id=a.provider_id
            WHERE a.status!='resolved' AND a.first_detected_at<? AND (a.suppressed_until IS NULL OR a.suppressed_until<=?) ORDER BY a.first_detected_at ASC LIMIT 50""", (stale_before, now)).fetchall()
        created = connection.execute("SELECT count(*) FROM alerts WHERE first_detected_at>=?", (since,)).fetchone()[0]
    ack_times = [value for value in (seconds_between(row["first_detected_at"], row["acknowledged_at"]) for row in acknowledged) if value is not None and value >= 0]
    resolve_times = [value for value in (seconds_between(row["first_detected_at"], row["resolved_at"]) for row in resolved) if value is not None and value >= 0]
    auto_resolved = sum(1 for row in resolved if (row["resolution_note"] or "").startswith("후속 일일점검"))
    return {
        "days": days, "since": since, "created": created,
        "mtta_seconds": sum(ack_times) / len(ack_times) if ack_times else None, "acknowledged": len(ack_times),
        "mttr_seconds": sum(resolve_times) / len(resolve_times) if resolve_times else None, "resolved": len(resolve_times), "auto_resolved": auto_resolved,
        "by_severity": [dict(row) for row in severity_rows],
        "recurring": [dict(row) for row in recurring],
        "stale": [dict(row) for row in stale], "stale_count": len(stale), "stale_days": 3,
    }


# --- Infrastructure inventory -------------------------------------------------------------------

def _ensure_inventory_table(connection: sqlite3.Connection) -> None:
    connection.execute("""CREATE TABLE IF NOT EXISTS provider_inventory (
        id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, collected_at TEXT NOT NULL, duration_seconds REAL,
        status TEXT NOT NULL, payload TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_provider_inventory_provider ON provider_inventory(provider_id, collected_at DESC)")


def _inventory_meta(row: sqlite3.Row, payload: dict | None = None) -> dict:
    payload = payload if payload is not None else json.loads(row["payload"])
    nodes = payload.get("nodes") or []
    capacity = (payload.get("capacity") or {}).get("totals") or {}
    return {
        "id": row["id"], "provider_id": row["provider_id"], "collected_at": row["collected_at"], "duration_seconds": row["duration_seconds"], "status": row["status"],
        "node_count": len(nodes), "reachable_nodes": sum(1 for node in nodes if node.get("reachable")),
        "hypervisors": capacity.get("hypervisors", 0), "instances": ((payload.get("capacity") or {}).get("instances") or {}).get("total", 0),
        "storage_backend": (payload.get("storage") or {}).get("backend", "none"),
    }


def save_inventory(provider_id: str, status: str, duration_seconds: float | None, payload: dict, keep: int = 10) -> str:
    inventory_id = uuid.uuid4().hex
    collected_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        _ensure_inventory_table(connection)
        connection.execute("INSERT INTO provider_inventory (id, provider_id, collected_at, duration_seconds, status, payload) VALUES (?, ?, ?, ?, ?, ?)",
                           (inventory_id, provider_id, collected_at, duration_seconds, status, json.dumps(payload, ensure_ascii=False)))
        stale = connection.execute("SELECT id FROM provider_inventory WHERE provider_id=? ORDER BY collected_at DESC LIMIT -1 OFFSET ?", (provider_id, keep)).fetchall()
        if stale:
            connection.executemany("DELETE FROM provider_inventory WHERE id=?", [(row["id"],) for row in stale])
    return inventory_id


def latest_inventory(provider_id: str) -> dict | None:
    with _connect() as connection:
        _ensure_inventory_table(connection)
        row = connection.execute("SELECT * FROM provider_inventory WHERE provider_id=? ORDER BY collected_at DESC LIMIT 1", (provider_id,)).fetchone()
    if not row:
        return None
    payload = json.loads(row["payload"])
    return {**_inventory_meta(row, payload), "payload": payload}


def get_inventory(provider_id: str, inventory_id: str) -> dict | None:
    with _connect() as connection:
        _ensure_inventory_table(connection)
        row = connection.execute("SELECT * FROM provider_inventory WHERE provider_id=? AND id=?", (provider_id, inventory_id)).fetchone()
    if not row:
        return None
    payload = json.loads(row["payload"])
    return {**_inventory_meta(row, payload), "payload": payload}


def list_inventories(provider_id: str, limit: int = 10) -> list[dict]:
    with _connect() as connection:
        _ensure_inventory_table(connection)
        rows = connection.execute("SELECT * FROM provider_inventory WHERE provider_id=? ORDER BY collected_at DESC LIMIT ?", (provider_id, limit)).fetchall()
    return [_inventory_meta(row) for row in rows]


def delete_provider_inventories(provider_id: str) -> int:
    with _connect() as connection:
        _ensure_inventory_table(connection)
        cursor = connection.execute("DELETE FROM provider_inventory WHERE provider_id=?", (provider_id,))
    return cursor.rowcount


# --- Monitoring extensions -----------------------------------------------------------------------
# Collector credentials are Fernet-encrypted with the same master key as SSH secrets; threshold alerts
# from the monitoring evaluator live in the alerts table under category "monitoring" (source_key monitor:*).

def encrypt_secret(text: str) -> str:
    return _cipher().encrypt((text or "").encode("utf-8")).decode("ascii")


def decrypt_secret(token: str) -> str:
    if not token:
        return ""
    try:
        return _cipher().decrypt(token.encode("ascii")).decode("utf-8")
    except Exception:  # noqa: BLE001 - a rotated master key leaves the token undecryptable; treat as unset
        return ""


def _monitoring_item_key(source_key: str) -> str:
    parts = source_key.split(":")
    return parts[1] if len(parts) > 1 else source_key


def upsert_monitoring_alert(provider_id: str, source_key: str, severity: str, title: str, description: str, target: str, category: str = "monitoring") -> dict:
    """Create or refresh one threshold (or security) alert; repeats update last_detected_at/severity instead of duplicating."""
    now = datetime.now(timezone.utc).isoformat()
    hostnames = [target] if target else []
    with _connect() as connection:
        windows = _active_maintenance_windows(connection, provider_id, now)
        suppressed_until = _maintenance_suppression(windows, hostnames, _monitoring_item_key(source_key))
        row = connection.execute("SELECT id,status,severity,suppressed_until FROM alerts WHERE provider_id=? AND source_key=? ORDER BY last_detected_at DESC LIMIT 1",
                                 (provider_id, source_key)).fetchone()
        if row and row["status"] != "resolved":
            connection.execute("UPDATE alerts SET severity=?,title=?,description=?,target=?,last_detected_at=?,suppressed_until=? WHERE id=?",
                               (severity, title, description, target, now, suppressed_until, row["id"]))
            if row["severity"] != severity:
                _record_alert_event(connection, row["id"], "severity", f"심각도 {row['severity']} → {severity}", "monitoring")
            was_suppressed = bool(row["suppressed_until"]) and row["suppressed_until"] > now
            if suppressed_until and not was_suppressed:
                _record_alert_event(connection, row["id"], "suppressed", f"정비 시간 창에 포함되어 {suppressed_until[:16].replace('T', ' ')} UTC까지 알림을 억제합니다.", "system")
            return {"id": row["id"], "created": False, "suppressed_until": suppressed_until}
        alert_id = str(uuid.uuid4())
        connection.execute("""INSERT INTO alerts
            (id,provider_id,check_id,source_key,category,severity,status,title,description,target,assignee,
             work_history_id,first_detected_at,last_detected_at,acknowledged_at,resolved_at,resolution_note,suppressed_until)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", (
            alert_id, provider_id, None, source_key, category, severity, "open", title, description, target, "", None, now, now, None, None, "", suppressed_until,
        ))
        _record_alert_event(connection, alert_id, "detected", f"모니터링 임계치 규칙이 감지했습니다 ({severity})." if category == "monitoring" else f"{title} ({severity})", category)
        if suppressed_until:
            _record_alert_event(connection, alert_id, "suppressed", f"정비 시간 창에 포함되어 {suppressed_until[:16].replace('T', ' ')} UTC까지 알림을 억제합니다.", "system")
    return {"id": alert_id, "created": True, "suppressed_until": suppressed_until}


def resolve_monitoring_alert(provider_id: str, source_key: str, note: str, category: str = "monitoring") -> bool:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        rows = connection.execute("SELECT id FROM alerts WHERE provider_id=? AND source_key=? AND category=? AND status!='resolved'", (provider_id, source_key, category)).fetchall()
        for row in rows:
            connection.execute("UPDATE alerts SET status='resolved',resolved_at=?,resolution_note=?,suppressed_until=NULL WHERE id=?", (now, note, row["id"]))
            _record_alert_event(connection, row["id"], "resolved", note, category)
    return bool(rows)


def list_open_monitoring_alert_keys(provider_id: str) -> set[str]:
    with _connect() as connection:
        rows = connection.execute("SELECT DISTINCT source_key FROM alerts WHERE provider_id=? AND category='monitoring' AND status!='resolved'", (provider_id,)).fetchall()
    return {row["source_key"] for row in rows}

