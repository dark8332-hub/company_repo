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
    return connection


def save_provider(data: dict, credentials: dict) -> str:
    provider_id = str(uuid.uuid4())
    encrypted = _cipher().encrypt(json.dumps(credentials).encode())
    with _connect() as connection:
        connection.execute("INSERT INTO providers VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (
            provider_id, data["name"], data["vip"], data["port"], data["username"],
            data["auth_method"], encrypted, data["fingerprint"], data["controller_hostname"],
            data["sudo_mode"], json.dumps(data["available_tools"]), datetime.now(timezone.utc).isoformat(),
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
    return data


def save_check(provider_id: str, status: str, result: dict) -> str:
    check_id = str(uuid.uuid4())
    checked_at = datetime.now(timezone.utc).isoformat()
    with _connect() as connection:
        connection.execute("INSERT INTO check_results VALUES (?,?,?,?,?)", (check_id, provider_id, status, json.dumps(result), checked_at))
    return check_id


def latest_check(provider_id: str) -> dict | None:
    with _connect() as connection:
        row = connection.execute("SELECT id,status,result,checked_at FROM check_results WHERE provider_id=? ORDER BY checked_at DESC LIMIT 1", (provider_id,)).fetchone()
    return {**dict(row), "result": json.loads(row["result"])} if row else None


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


def delete_provider(provider_id: str) -> bool:
    with _connect() as connection:
        exists = connection.execute("SELECT 1 FROM providers WHERE id=?", (provider_id,)).fetchone()
        if not exists:
            return False
        connection.execute("DELETE FROM check_results WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM provider_nodes WHERE provider_id=?", (provider_id,))
        connection.execute("DELETE FROM providers WHERE id=?", (provider_id,))
    return True
