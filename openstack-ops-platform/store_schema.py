"""SQLite schema creation and compatible migrations, separate from store operations."""
import sqlite3
from datetime import datetime, timezone


def initialize_schema(connection: sqlite3.Connection) -> None:
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
    # 노드 호스트 키는 지문만으로는 접속을 고정할 수 없다. 탐색 때 Controller 에서 받아 온
    # 공개키 원문을 함께 보관해, 배포 서버의 ~/.ssh/known_hosts 없이도 검증할 수 있게 한다.
    host_key_columns = {row[1] for row in connection.execute("PRAGMA table_info(provider_host_keys)")}
    if "public_key" not in host_key_columns:
        connection.execute("ALTER TABLE provider_host_keys ADD COLUMN public_key TEXT NOT NULL DEFAULT ''")
    if "role" not in host_key_columns:
        connection.execute("ALTER TABLE provider_host_keys ADD COLUMN role TEXT NOT NULL DEFAULT ''")

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
    # Issue notes: a Confluence-style page per issue with Markdown body, code snippets and a timeline.
    connection.execute("""CREATE TABLE IF NOT EXISTS issues (
        id TEXT PRIMARY KEY, number INTEGER NOT NULL UNIQUE, provider_id TEXT, title TEXT NOT NULL,
        status TEXT NOT NULL, severity TEXT NOT NULL, category TEXT NOT NULL, tags TEXT NOT NULL DEFAULT '[]',
        body TEXT NOT NULL DEFAULT '', assignee TEXT NOT NULL DEFAULT '', reporter TEXT NOT NULL DEFAULT '',
        target TEXT NOT NULL DEFAULT '', resolution TEXT NOT NULL DEFAULT '',
        alert_id TEXT, work_history_id TEXT, check_id TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, resolved_at TEXT
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_issues_status_updated ON issues(status, updated_at DESC)")
    connection.execute("""CREATE TABLE IF NOT EXISTS issue_snippets (
        id TEXT PRIMARY KEY, issue_id TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, title TEXT NOT NULL DEFAULT '',
        path TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'text', code TEXT NOT NULL,
        created_by TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(issue_id) REFERENCES issues(id)
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_issue_snippets_issue ON issue_snippets(issue_id, position)")
    connection.execute("""CREATE TABLE IF NOT EXISTS issue_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT, issue_id TEXT NOT NULL, created_at TEXT NOT NULL, actor TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL, text TEXT NOT NULL DEFAULT ''
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_issue_events_issue ON issue_events(issue_id, id)")
