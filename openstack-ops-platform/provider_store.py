import json
import os
import sqlite3
import uuid
from datetime import datetime, timezone
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
    check_columns = {row[1] for row in connection.execute("PRAGMA table_info(check_results)")}
    if "summary" not in check_columns:
        connection.execute("ALTER TABLE check_results ADD COLUMN summary TEXT")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_check_results_provider_checked ON check_results(provider_id,checked_at DESC)")
    connection.execute("""CREATE TABLE IF NOT EXISTS check_schedules (
        provider_id TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0, run_time TEXT NOT NULL DEFAULT '09:00',
        selected_items TEXT, last_run_at TEXT, last_status TEXT, last_check_id TEXT, last_error TEXT, updated_at TEXT NOT NULL,
        FOREIGN KEY(provider_id) REFERENCES providers(id)
    )""")
    return connection


def save_provider(data: dict, credentials: dict) -> str:
    provider_id = str(uuid.uuid4())
    encrypted = _cipher().encrypt(json.dumps(credentials).encode())
    created_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("INSERT INTO providers VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (
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
        row = connection.execute("SELECT id,status,result,checked_at FROM check_results WHERE provider_id=? AND id=?", (provider_id, check_id)).fetchone()
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
    discovered_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("DELETE FROM provider_nodes WHERE provider_id=?", (provider_id,))
        connection.executemany(
            "INSERT INTO provider_nodes VALUES (?,?,?,?,?,?)",
            [(provider_id, node["hostname"], node["role"], node.get("address", node["hostname"]), node["source"], discovered_at) for node in nodes],
        )


def list_provider_nodes(provider_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute(
            "SELECT hostname,role,address,source,discovered_at FROM provider_nodes WHERE provider_id=? ORDER BY CASE role WHEN 'controller' THEN 0 ELSE 1 END, hostname",
            (provider_id,),
        ).fetchall()
    return [dict(row) for row in rows]


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
        cursor = connection.execute("DELETE FROM work_histories WHERE id=?", (history_id,))
    return cursor.rowcount > 0


def sync_check_alerts(provider_id: str, check_id: str, items: dict) -> None:
    now = datetime.now(timezone.utc).isoformat()
    active_keys = set()
    with _connect() as connection:
        for key, item in items.items():
            state = item.get("status")
            if state not in {"warning", "unavailable"}:
                continue
            source_key = f"inspection:{key}"
            active_keys.add(source_key)
            severity = "critical" if state == "unavailable" else "warning"
            title = item.get("name") or key.replace("_", " ").title()
            description = item.get("note") or item.get("result") or "일일점검에서 이상 상태를 감지했습니다."
            target = ", ".join(detail.get("hostname", "") for detail in item.get("nodes", []) if detail.get("status") in {"warning", "unavailable"})
            row = connection.execute("""SELECT id,status FROM alerts
                WHERE provider_id=? AND source_key=? ORDER BY last_detected_at DESC LIMIT 1""", (provider_id, source_key)).fetchone()
            if row and row["status"] != "resolved":
                connection.execute("""UPDATE alerts SET check_id=?,severity=?,title=?,description=?,target=?,
                    last_detected_at=? WHERE id=?""", (check_id, severity, title, description, target, now, row["id"]))
            else:
                connection.execute("""INSERT INTO alerts
                    (id,provider_id,check_id,source_key,category,severity,status,title,description,target,assignee,
                     work_history_id,first_detected_at,last_detected_at,acknowledged_at,resolved_at,resolution_note)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", (
                    str(uuid.uuid4()), provider_id, check_id, source_key, "inspection", severity, "open", title,
                    description, target, "", None, now, now, None, None, "",
                ))
        # Only items that were actually checked this run can clear an alert; a partial run must not resolve the rest.
        checked_keys = {f"inspection:{key}" for key in items}
        open_rows = connection.execute("""SELECT id,source_key FROM alerts
            WHERE provider_id=? AND category='inspection' AND status!='resolved'""", (provider_id,)).fetchall()
        for row in open_rows:
            if row["source_key"] in checked_keys and row["source_key"] not in active_keys:
                connection.execute("UPDATE alerts SET status='resolved',resolved_at=?,resolution_note=? WHERE id=?",
                                   (now, "후속 일일점검에서 정상 상태를 확인하여 자동 해소", row["id"]))


def list_alerts(provider_id: str = "", status: str = "", severity: str = "", query: str = "", limit: int = 300) -> list[dict]:
    clauses, values = [], []
    if provider_id: clauses.append("a.provider_id=?"); values.append(provider_id)
    if status: clauses.append("a.status=?"); values.append(status)
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
    return [dict(row) for row in rows]


def get_alert(alert_id: str) -> dict | None:
    return next(iter(list_alerts_by_id(alert_id)), None)


def list_alerts_by_id(alert_id: str) -> list[dict]:
    with _connect() as connection:
        rows = connection.execute("""SELECT a.*,p.name AS provider_name,w.title AS work_history_title
            FROM alerts a LEFT JOIN providers p ON p.id=a.provider_id
            LEFT JOIN work_histories w ON w.id=a.work_history_id WHERE a.id=?""", (alert_id,)).fetchall()
    return [dict(row) for row in rows]


def update_alert(alert_id: str, status: str, assignee: str, resolution_note: str, work_history_id: str | None) -> dict | None:
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        cursor = connection.execute("""UPDATE alerts SET status=?,assignee=?,resolution_note=?,work_history_id=?,
            acknowledged_at=CASE WHEN ?='acknowledged' AND acknowledged_at IS NULL THEN ? ELSE acknowledged_at END,
            resolved_at=CASE WHEN ?='resolved' THEN ? WHEN ?!='resolved' THEN NULL ELSE resolved_at END WHERE id=?""",
            (status, assignee, resolution_note, work_history_id, status, now, status, now, status, alert_id))
    return get_alert(alert_id) if cursor.rowcount else None


def alert_summary() -> dict:
    with _connect() as connection:
        rows = connection.execute("SELECT status,severity,count(*) count FROM alerts GROUP BY status,severity").fetchall()
    active = sum(row["count"] for row in rows if row["status"] != "resolved")
    return {"active": active, "critical": sum(row["count"] for row in rows if row["status"] != "resolved" and row["severity"] == "critical"), "groups": [dict(row) for row in rows]}


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
        connection.execute("UPDATE work_histories SET provider_id=NULL WHERE provider_id=?", (provider_id,))
        connection.execute("UPDATE alerts SET provider_id=NULL WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM providers WHERE id=?", (provider_id,))
    return True
