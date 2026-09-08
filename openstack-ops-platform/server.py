import asyncio
import base64
import ipaddress
import json
import logging
import os
import re
import secrets
import shlex
import socket
import subprocess
import tempfile
import uuid
from collections import Counter
from contextvars import ContextVar
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import quote
from zoneinfo import ZoneInfo

import asyncssh
import httpx
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse, Response
from pydantic import BaseModel, Field, model_validator, field_validator
from inspection_report import build_inspection_pdf, build_issue_report_pdf
from inspection_excel import build_inspection_workbook, inspection_workbook_filename
from runbooks import effective_runbook
from provider_store import (
    database_credentials_status, delete_check_exception, delete_database_credentials, delete_provider, delete_provider_host_key, get_provider, latest_check, list_check_exceptions,
    is_provider_host_key_trusted, list_host_key_events, list_provider_host_keys, list_provider_nodes,
    provider_host_key_material,
    list_providers, mark_provider_host_key_seen, save_check, save_check_exception, save_provider,
    delete_provider_node, update_provider, update_provider_node, upsert_provider_node,
    save_database_credentials, save_provider_nodes, sudo_password_configured, sudo_status, trust_provider_host_key, update_provider_sudo,
    delete_work_history, get_work_history, list_work_histories, save_work_history, update_work_history,
    alert_summary, get_alert, list_alerts, sync_check_alerts, update_alert,
    add_alert_comment, alert_stats, bulk_update_alerts, delete_maintenance_window, get_maintenance_window, is_active_alert, list_alert_events,
    list_maintenance_windows, save_maintenance_window,
    delete_custom_check, list_custom_checks, save_custom_check,
    check_summary, get_check, get_check_schedule, list_checks, list_enabled_check_schedules, previous_check_summary,
    record_schedule_run, save_check_schedule,
    check_storage_stats, delete_log_exclusion, list_log_exclusions, prune_check_results, save_log_exclusion,
    active_session_count, admin_account_info, change_admin_password, create_session, delete_other_sessions, delete_session,
    ensure_admin_account, get_session, purge_expired_sessions, reset_admin_password, verify_admin_password,
    audit_log_facets, delete_setting, get_setting, get_setting_info, list_audit_logs, list_settings, prune_audit_logs, record_audit, set_setting,
    decrypt_secret, encrypt_secret, list_open_monitoring_alert_keys, resolve_monitoring_alert, upsert_monitoring_alert,
)

from fastapi import File, UploadFile  # work history attachments
from provider_store import (  # issue notes
    ISSUE_CATEGORIES, ISSUE_LANGUAGES, ISSUE_SEVERITIES, ISSUE_STATUSES, ISSUE_TRANSITIONS, add_issue_comment, add_issue_snippet,
    delete_issue, delete_issue_snippet, get_alert as store_get_alert, get_check as store_get_check, get_issue, get_issue_snippet,
    issue_summary, list_issue_events, list_issue_snippets, list_issues, save_issue, transition_issue, update_issue, update_issue_snippet,
)
from provider_store import (  # work history extensions
    WORK_TRANSITIONS, add_work_history_attachment, delete_work_history_attachment, get_work_history_attachment,
    list_work_histories_for_month, list_work_history_attachments, set_work_history_check, transition_work_history,
)

BASE_DIR = Path(__file__).resolve().parent
app = FastAPI(title="OKESTRO OpenStack Operations API", version="0.1.0")
CHECK_PROGRESS: dict[str, dict] = {}
CHECK_TASKS: dict[str, asyncio.Task] = {}
BACKGROUND_TASKS: set[asyncio.Task] = set()
logger = logging.getLogger("uvicorn.error")
# The request being served, so audit() can name the operator without threading a Request through every helper.
CURRENT_REQUEST: ContextVar[Request | None] = ContextVar("current_request", default=None)


def schedule_timezone() -> ZoneInfo:
    """Scheduled checks follow the operators' clock (default Asia/Seoul), not the container's UTC clock."""
    try:
        return ZoneInfo(RUNTIME["timezone"])
    except Exception:
        return ZoneInfo("UTC")

def env_int(name: str, default: int, minimum: int = 0, maximum: int = 100000) -> int:
    try:
        return min(max(int(os.environ.get(name, default)), minimum), maximum)
    except (TypeError, ValueError):
        return default


# --- Authentication -----------------------------------------------------------------------------
# One administrator account, server-side sessions in SQLite, HttpOnly cookie. Every /api/* route and
# every page except the login page requires a valid session; /api/health stays open for Docker/systemd probes.
SESSION_COOKIE = "okestro_session"
# Default initial password used when ADMIN_PASSWORD is not set; the first login must change it.
DEFAULT_ADMIN_PASSWORD = "Okestro2018@"
SESSION_TTL_HOURS = env_int("SESSION_TTL_HOURS", 8, 1, 24 * 30)
LOGIN_MAX_FAILURES = 5
LOGIN_LOCK_SECONDS = 300
LOGIN_FAILURES: dict[str, dict] = {}
PUBLIC_PATHS = {"/login", "/api/auth/login", "/api/health", "/styles.css", "/login.js"}
ADMIN_USERNAME_PATTERN = re.compile(r"^[A-Za-z0-9._-]{2,64}$")


def client_address(request: Request) -> str:
    return request.client.host if request.client else ""


def login_locked(address: str) -> int:
    """Seconds remaining on the lockout for this address, 0 when not locked."""
    entry = LOGIN_FAILURES.get(address)
    if not entry:
        return 0
    if entry["count"] < LOGIN_MAX_FAILURES:
        return 0
    remaining = LOGIN_LOCK_SECONDS - (datetime.now(timezone.utc) - entry["last"]).total_seconds()
    if remaining <= 0:
        LOGIN_FAILURES.pop(address, None)
        return 0
    return int(remaining) + 1


def record_login_failure(address: str) -> None:
    entry = LOGIN_FAILURES.setdefault(address, {"count": 0, "last": datetime.now(timezone.utc)})
    entry["count"] += 1
    entry["last"] = datetime.now(timezone.utc)


def cookie_secure(request: Request) -> bool:
    forwarded = request.headers.get("x-forwarded-proto", "")
    return os.environ.get("SESSION_COOKIE_SECURE", "").lower() in {"1", "true", "yes"} or request.url.scheme == "https" or forwarded == "https"


def set_session_cookie(response: Response, request: Request, token: str) -> None:
    response.set_cookie(SESSION_COOKIE, token, max_age=SESSION_TTL_HOURS * 3600, httponly=True, samesite="lax", secure=cookie_secure(request), path="/")


def clear_session_cookie(response: Response) -> None:
    response.delete_cookie(SESSION_COOKIE, path="/")


def validate_new_password(password: str) -> None:
    if len(password) < 8 or len(password) > 128:
        raise HTTPException(400, "비밀번호는 8자 이상 128자 이하로 입력하세요.")
    kinds = sum(bool(re.search(pattern, password)) for pattern in (r"[A-Za-z]", r"\d", r"[^A-Za-z0-9]"))
    if kinds < 2:
        raise HTTPException(400, "비밀번호는 영문, 숫자, 특수문자 중 두 종류 이상을 섞어 입력하세요.")


@app.middleware("http")
async def require_login(request: Request, call_next):
    path = request.url.path
    request.state.user = None
    session = get_session(request.cookies.get(SESSION_COOKIE, ""))
    if session:
        request.state.user = session
    if path in PUBLIC_PATHS or path.startswith("/fonts/") or session:
        context_token = CURRENT_REQUEST.set(request)
        try:
            return await call_next(request)
        finally:
            CURRENT_REQUEST.reset(context_token)
    if path.startswith("/api/"):
        return JSONResponse({"detail": "로그인이 필요합니다."}, status_code=401, headers={"Cache-Control": "no-store"})
    next_url = path + (f"?{request.url.query}" if request.url.query else "")
    return RedirectResponse(f"/login?next={quote(next_url, safe='')}", status_code=302, headers={"Cache-Control": "no-store"})


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=1, max_length=128)


def session_payload(session: dict) -> dict:
    account = admin_account_info() or {}
    return {
        "username": session["username"], "must_change_password": session.get("must_change_password", False),
        "login_at": session.get("created_at"), "expires_at": session.get("expires_at"),
        "password_changed_at": account.get("password_changed_at"), "last_login_at": account.get("last_login_at"),
        "active_sessions": active_session_count(), "session_ttl_hours": SESSION_TTL_HOURS,
    }


@app.post("/api/auth/login")
async def auth_login(payload: LoginRequest, request: Request):
    address = client_address(request)
    remaining = login_locked(address)
    if remaining:
        raise HTTPException(429, f"로그인 실패가 반복되어 잠시 차단되었습니다. {remaining}초 후 다시 시도하세요.")
    account = verify_admin_password(payload.username.strip(), payload.password)
    if not account:
        record_login_failure(address)
        logger.warning("Login failed for %r from %s", payload.username.strip(), address or "-")
        audit("auth.login", "account", payload.username.strip(), payload.username.strip(), "아이디 또는 비밀번호 불일치", outcome="failure", actor=payload.username.strip())
        raise HTTPException(401, "아이디 또는 비밀번호가 올바르지 않습니다.")
    LOGIN_FAILURES.pop(address, None)
    purge_expired_sessions()
    token, expires_at = create_session(account["username"], SESSION_TTL_HOURS, address, request.headers.get("user-agent", ""))
    logger.info("Login succeeded for %r from %s", account["username"], address or "-")
    audit("auth.login", "account", account["username"], account["username"], "초기 비밀번호 변경 필요" if account["must_change_password"] else "", actor=account["username"])
    response = JSONResponse({"username": account["username"], "must_change_password": account["must_change_password"], "expires_at": expires_at})
    set_session_cookie(response, request, token)
    return response


@app.post("/api/auth/logout")
async def auth_logout(request: Request):
    if request.state.user:
        audit("auth.logout", "account", request.state.user["username"], request.state.user["username"])
    delete_session(request.cookies.get(SESSION_COOKIE, ""))
    response = JSONResponse({"status": "logged_out"})
    clear_session_cookie(response)
    return response


@app.get("/api/auth/session")
async def auth_session(request: Request):
    return session_payload(request.state.user)


@app.post("/api/auth/password")
async def auth_change_password(payload: PasswordChangeRequest, request: Request):
    user = request.state.user
    if not verify_admin_password(user["username"], payload.current_password):
        raise HTTPException(400, "현재 비밀번호가 올바르지 않습니다.")
    if payload.current_password == payload.new_password:
        raise HTTPException(400, "새 비밀번호는 현재 비밀번호와 달라야 합니다.")
    validate_new_password(payload.new_password)
    change_admin_password(payload.new_password)
    revoked = delete_other_sessions(request.cookies.get(SESSION_COOKIE, ""))
    logger.info("Administrator password changed by %r from %s (revoked %d other sessions)", user["username"], client_address(request) or "-", revoked)
    audit("auth.password_change", "account", user["username"], user["username"], f"다른 로그인 세션 {revoked}개 해제")
    return {"status": "changed", "revoked_sessions": revoked, "session": session_payload(get_session(request.cookies.get(SESSION_COOKIE, "")) or user)}


@app.on_event("startup")
async def ensure_administrator():
    username = os.environ.get("ADMIN_USERNAME", "admin").strip() or "admin"
    if not ADMIN_USERNAME_PATTERN.match(username):
        logger.error("ADMIN_USERNAME %r is invalid (2~64 chars of letters, digits, '.', '_', '-'); using 'admin'", username)
        username = "admin"
    password = os.environ.get("ADMIN_PASSWORD", "")
    reset = os.environ.get("ADMIN_PASSWORD_RESET", "").lower() in {"1", "true", "yes"}
    if reset and password:
        reset_admin_password(username, password, must_change_password=True)
        logger.warning("Administrator credentials reset from ADMIN_PASSWORD (ADMIN_PASSWORD_RESET is set); all sessions revoked. Unset ADMIN_PASSWORD_RESET after login.")
        return
    default_used = not password
    if default_used:
        password = DEFAULT_ADMIN_PASSWORD
    created = ensure_admin_account(username, password, must_change_password=True)
    if created and default_used:
        logger.warning("Administrator account %r created with the default initial password (see README); change it at first login", username)
    elif created:
        logger.info("Administrator account %r created from ADMIN_PASSWORD (password change required at first login)", username)
    purge_expired_sessions()


# Inspection time limits (seconds). Every remote command carries its own limit so one hung
# command turns into a single "확인 불가" item instead of discarding a whole node's result.
INSPECTION_TIMEOUTS = {
    "node_script": env_int("INSPECTION_NODE_TIMEOUT", 240, 60, 3600),           # whole per-node script
    "controller_script": env_int("INSPECTION_CONTROLLER_TIMEOUT", 600, 60, 3600),  # whole active-controller script
    "command": env_int("INSPECTION_COMMAND_TIMEOUT", 20, 5, 600),               # one system command on a node
    "log_scan": env_int("INSPECTION_LOG_TIMEOUT", 45, 10, 600),                 # one service's log scan on a node
    "openstack": env_int("INSPECTION_OPENSTACK_TIMEOUT", 45, 10, 600),          # one OpenStack CLI / cluster command
}
INSPECTION_NODE_CONCURRENCY = env_int("INSPECTION_NODE_CONCURRENCY", 8, 1, 64)
# Retention: results older than max_age are deleted, raw outputs older than raw_age are stripped,
# the newest keep_latest results per provider are never touched.
RETENTION_POLICY = {
    "max_age_days": env_int("INSPECTION_RETENTION_DAYS", 180, 0, 3650),
    "raw_age_days": env_int("INSPECTION_RAW_RETENTION_DAYS", 30, 0, 3650),
    "max_per_provider": env_int("INSPECTION_RETENTION_MAX", 200, 0, 100000),
    "keep_latest": env_int("INSPECTION_RETENTION_KEEP", 10, 1, 1000),
}
LOG_SERVICES = ("nova", "neutron", "cinder", "glance", "manila", "octavia", "masakari", "swift", "heat", "system")
# node metric key → provider threshold field (provider_setting(..., "thresholds"))
METRIC_THRESHOLD_FIELDS = {"cpu_used_percent": "cpu_warning", "memory_used_percent": "memory_warning", "disk_used_percent": "disk_warning"}

# --- Server-side settings ------------------------------------------------------------------------
# Environment variables provide the defaults; values saved from the settings screen (app_settings table)
# override them at startup and immediately when changed. INSPECTION_TIMEOUTS / RETENTION_POLICY are
# mutated in place so every reader keeps working unchanged.
RUNTIME = {
    "node_concurrency": INSPECTION_NODE_CONCURRENCY,
    "timezone": os.environ.get("INSPECTION_TIMEZONE", "Asia/Seoul"),
    "audit_max_age_days": env_int("AUDIT_RETENTION_DAYS", 365, 0, 3650),
}
MENU_KEYS = ["dashboard", "providers", "infrastructure", "daily-inspection", "monitoring", "alerts", "history", "issues"]
COMMON_TIMEZONES = ["Asia/Seoul", "UTC", "Asia/Tokyo", "Asia/Shanghai", "Asia/Singapore", "Asia/Ho_Chi_Minh", "Asia/Jakarta", "Asia/Kolkata", "Europe/London", "Europe/Berlin", "America/New_York", "America/Los_Angeles"]
AUDIT_ACTION_LABELS = {
    "auth.login": "로그인", "auth.logout": "로그아웃", "auth.password_change": "비밀번호 변경",
    "provider.create": "공급자 등록", "provider.update": "공급자 수정", "provider.delete": "공급자 삭제", "provider.discover": "클러스터 탐색",
    "provider.db_credentials.set": "DB 인증 등록", "provider.db_credentials.delete": "DB 인증 삭제",
    "provider.sudo_credentials.set": "sudo 비밀번호 등록", "provider.sudo_credentials.delete": "sudo 비밀번호 삭제",
    "provider.host_key.approve": "SSH 지문 승인", "provider.host_key.revoke": "SSH 지문 폐기", "provider.host_key.changed": "SSH 지문 변경 감지",
    "provider.node.add": "노드 추가", "provider.node.update": "노드 수정", "provider.node.delete": "노드 삭제", "provider.diagnose": "연결 진단",
    "check.run": "일일점검 실행", "check.scheduled": "예약 점검 실행", "check.schedule.update": "예약 설정 변경", "check.cancel": "점검 취소",
    "check.exception.create": "예외 등록", "check.exception.delete": "예외 삭제",
    "check.custom.create": "사용자 정의 점검 등록", "check.custom.update": "사용자 정의 점검 수정", "check.custom.delete": "사용자 정의 점검 삭제", "check.custom.test": "사용자 정의 점검 시험",
    "check.log_exclusion.create": "로그 제외 패턴 등록", "check.log_exclusion.delete": "로그 제외 패턴 삭제",
    "alert.update": "알림 처리", "alert.bulk": "알림 일괄 처리", "alert.comment": "알림 코멘트", "maintenance.create": "정비 시간 창 등록", "maintenance.delete": "정비 시간 창 삭제", "work_history.create": "작업 이력 등록", "work_history.update": "작업 이력 수정", "work_history.delete": "작업 이력 삭제",
    "work_history.transition": "작업 상태 변경", "work_history.check": "작업 전후 점검", "work_history.attachment.add": "작업 첨부 추가", "work_history.attachment.delete": "작업 첨부 삭제", "work_history.export": "작업 이력 내보내기",
    "issue.create": "이슈 등록", "issue.update": "이슈 수정", "issue.delete": "이슈 삭제", "issue.transition": "이슈 상태 변경", "issue.comment": "이슈 코멘트",
    "issue.snippet.add": "이슈 코드 추가", "issue.snippet.update": "이슈 코드 수정", "issue.snippet.delete": "이슈 코드 삭제", "issue.export": "이슈 내보내기",
    "settings.update": "설정 변경", "settings.reset": "설정 초기화", "provider.settings.update": "공급자 설정 변경", "provider.settings.reset": "공급자 설정 초기화", "retention.prune": "이력 정리 실행", "report.export": "보고서 내보내기", "inventory.collect": "인벤토리 수집",
    "monitoring.settings.update": "모니터링 수집원 설정", "monitoring.test": "모니터링 연결 테스트", "monitoring.rules.update": "임계치 알림 규칙 변경", "monitoring.rules.reset": "임계치 알림 규칙 초기화", "monitoring.evaluate": "임계치 즉시 평가",
}
SETTING_SPECS = {
    "inspection.timeouts": {"label": "점검 실행 제한 시간", "fields": {"node_script": (60, 3600), "controller_script": (60, 3600), "command": (5, 600), "log_scan": (10, 600), "openstack": (10, 600), "node_concurrency": (1, 64)}},
    "inspection.retention": {"label": "점검 이력 보관 정책", "fields": {"max_age_days": (0, 3650), "raw_age_days": (0, 3650), "max_per_provider": (0, 100000), "keep_latest": (1, 1000)}},
    "inspection.timezone": {"label": "예약 실행 기준 시간대", "timezone": True},
    "audit.retention": {"label": "감사 로그 보관 기간", "fields": {"max_age_days": (0, 3650)}},
    "ui.menus": {"label": "왼쪽 메뉴 표시", "per_user": True, "list_of": MENU_KEYS},
    "ui.dashboard": {"label": "대시보드 구성", "per_user": True, "json": True},
}
ENV_DEFAULTS = {
    "inspection.timeouts": {**INSPECTION_TIMEOUTS, "node_concurrency": INSPECTION_NODE_CONCURRENCY},
    "inspection.retention": dict(RETENTION_POLICY),
    "inspection.timezone": {"timezone": RUNTIME["timezone"]},
    "audit.retention": {"max_age_days": RUNTIME["audit_max_age_days"]},
    "ui.menus": {"visible": list(MENU_KEYS)},
    "ui.dashboard": {},
}


def setting_storage_key(key: str, username: str | None) -> str:
    return f"{key}:{username}" if SETTING_SPECS[key].get("per_user") else key


def validate_setting(key: str, value) -> dict:
    spec = SETTING_SPECS.get(key)
    if not spec:
        raise HTTPException(404, "지원하지 않는 설정 항목입니다.")
    if not isinstance(value, dict):
        raise HTTPException(400, "설정 값은 객체여야 합니다.")
    if "fields" in spec:
        normalized = {}
        for field, (minimum, maximum) in spec["fields"].items():
            raw = value.get(field, ENV_DEFAULTS[key][field])
            try:
                number = int(raw)
            except (TypeError, ValueError) as exc:
                raise HTTPException(400, f"{field} 값은 정수여야 합니다.") from exc
            if not minimum <= number <= maximum:
                raise HTTPException(400, f"{field} 값은 {minimum}~{maximum} 범위여야 합니다.")
            normalized[field] = number
        if key == "inspection.retention" and normalized["max_age_days"] and normalized["raw_age_days"] > normalized["max_age_days"]:
            raise HTTPException(400, "원본 출력 보관 기간은 결과 보관 기간보다 길 수 없습니다.")
        return normalized
    if spec.get("timezone"):
        name = str(value.get("timezone", "")).strip()
        try:
            ZoneInfo(name)
        except Exception as exc:
            raise HTTPException(400, f"알 수 없는 시간대입니다: {name or '-'}") from exc
        return {"timezone": name}
    if "list_of" in spec:
        # Stored as both lists: `hidden` is what the client applies, so a menu added later is visible until
        # someone hides it; `visible` stays for older clients.
        visible, hidden = value.get("visible"), value.get("hidden")
        if isinstance(hidden, list):
            visible = [item for item in spec["list_of"] if item not in hidden]
        if not isinstance(visible, list):
            raise HTTPException(400, "visible 목록이 필요합니다.")
        visible = [item for item in spec["list_of"] if item in visible]
        return {"visible": visible, "hidden": [item for item in spec["list_of"] if item not in visible]}
    if spec.get("json"):
        if len(json.dumps(value, ensure_ascii=False)) > 20000:
            raise HTTPException(400, "설정 값이 너무 큽니다.")
        return value
    return value


def apply_setting(key: str, value: dict) -> None:
    if key == "inspection.timeouts":
        INSPECTION_TIMEOUTS.update({field: value[field] for field in INSPECTION_TIMEOUTS})
        RUNTIME["node_concurrency"] = value["node_concurrency"]
    elif key == "inspection.retention":
        RETENTION_POLICY.update(value)
    elif key == "inspection.timezone":
        RUNTIME["timezone"] = value["timezone"]
    elif key == "audit.retention":
        RUNTIME["audit_max_age_days"] = value["max_age_days"]


def load_stored_settings() -> None:
    for key, spec in SETTING_SPECS.items():
        if spec.get("per_user"):
            continue
        stored = get_setting(key)
        if stored is None:
            continue
        try:
            apply_setting(key, validate_setting(key, stored))
        except HTTPException as exc:
            logger.warning("Stored setting %s ignored: %s", key, exc.detail)


def setting_snapshot(key: str, username: str | None) -> dict:
    spec = SETTING_SPECS[key]
    info = get_setting_info(setting_storage_key(key, username))
    default = ENV_DEFAULTS[key]
    value = info["value"] if info and info["value"] is not None else default
    return {"key": key, "label": spec["label"], "value": value, "default": default, "source": "stored" if info else "default",
            "updated_at": info["updated_at"] if info else None, "updated_by": info["updated_by"] if info else None, "per_user": bool(spec.get("per_user"))}


@app.on_event("startup")
async def apply_stored_settings():
    load_stored_settings()


# --- Per-provider settings (stored under app_settings key "provider:<id>:<name>") --------------------
PROVIDER_SETTING_SPECS = {
    "thresholds": {"label": "판정 임계치", "fields": {"cpu_warning": (50, 100), "memory_warning": (50, 100), "disk_warning": (50, 100), "log_error_warning": (0, 100000)}},
    "default_items": {"label": "기본 점검 항목", "keys": True},
    "profile": {"label": "공급자 프로필", "text": {"site": 100, "environment": 40, "contact": 200, "memo": 2000}, "tags": True},
    "monitoring": {"label": "모니터링 연결", "json": True},
    "runbooks": {"label": "조치 가이드", "json": True},
    "alert_rules": {"label": "알림 규칙", "json": True},
}
PROVIDER_SETTING_DEFAULTS = {
    "thresholds": {"cpu_warning": 80, "memory_warning": 80, "disk_warning": 80, "log_error_warning": 1},
    "default_items": {"selected": None},
    "profile": {"site": "", "environment": "", "contact": "", "memo": "", "tags": []},
    "monitoring": {},
    "runbooks": {},
    "alert_rules": {},
}


def provider_setting_key(provider_id: str, name: str) -> str:
    return f"provider:{provider_id}:{name}"


def provider_setting(provider_id: str, name: str) -> dict:
    """Stored value merged over the defaults, so callers can index fields without checking."""
    stored = get_setting(provider_setting_key(provider_id, name))
    default = PROVIDER_SETTING_DEFAULTS[name]
    if isinstance(default, dict) and isinstance(stored, dict):
        return {**default, **stored}
    return stored if stored is not None else default


def validate_provider_setting(provider_id: str, name: str, value) -> dict:
    spec = PROVIDER_SETTING_SPECS.get(name)
    if not spec:
        raise HTTPException(404, "지원하지 않는 공급자 설정입니다.")
    if not isinstance(value, dict):
        raise HTTPException(400, "설정 값은 객체여야 합니다.")
    if "fields" in spec:
        normalized = {}
        for field, (minimum, maximum) in spec["fields"].items():
            raw = value.get(field, PROVIDER_SETTING_DEFAULTS[name][field])
            try:
                number = int(raw)
            except (TypeError, ValueError) as exc:
                raise HTTPException(400, f"{field} 값은 정수여야 합니다.") from exc
            if not minimum <= number <= maximum:
                raise HTTPException(400, f"{field} 값은 {minimum}~{maximum} 범위여야 합니다.")
            normalized[field] = number
        return normalized
    if spec.get("keys"):
        selected = value.get("selected")
        if selected is None:
            return {"selected": None}
        if not isinstance(selected, list):
            raise HTTPException(400, "selected 목록이 필요합니다.")
        available = CHECK_KEYS | {item["key"] for item in list_custom_checks(provider_id)}
        return {"selected": [key for key in selected if key in available]}
    if "text" in spec:
        normalized = {}
        for field, limit in spec["text"].items():
            normalized[field] = str(value.get(field, "") or "").strip()[:limit]
        if spec.get("tags"):
            tags = value.get("tags", [])
            if not isinstance(tags, list):
                raise HTTPException(400, "tags 목록이 필요합니다.")
            normalized["tags"] = [str(tag).strip()[:30] for tag in tags if str(tag).strip()][:20]
        return normalized
    if name == "monitoring" and ("secret" in value or "secret_encrypted" in value):
        raise HTTPException(400, "수집원 인증 비밀은 PUT /api/providers/{id}/monitoring/settings 로만 저장할 수 있습니다.")
    if len(json.dumps(value, ensure_ascii=False)) > 50000:
        raise HTTPException(400, "설정 값이 너무 큽니다.")
    return value


def provider_setting_snapshot(provider_id: str, name: str) -> dict:
    info = get_setting_info(provider_setting_key(provider_id, name))
    return {"name": name, "label": PROVIDER_SETTING_SPECS[name]["label"], "value": provider_setting(provider_id, name), "default": PROVIDER_SETTING_DEFAULTS[name],
            "source": "stored" if info else "default", "updated_at": info["updated_at"] if info else None, "updated_by": info["updated_by"] if info else None}


# --- Audit trail ---------------------------------------------------------------------------------

def audit(action: str, target_type: str = "", target_id: str = "", target_name: str = "", detail: str = "", outcome: str = "success", actor: str | None = None) -> None:
    """Record who did what. Never raises: an audit failure must not break the operation it describes."""
    request = CURRENT_REQUEST.get()
    user = getattr(request.state, "user", None) if request else None
    try:
        record_audit(actor or (user["username"] if user else "scheduler"), action, target_type, target_id, target_name, detail, outcome,
                     client_address(request) if request else "", request.headers.get("user-agent", "") if request else "")
    except Exception:  # noqa: BLE001
        logger.exception("audit record failed for %s", action)


def provider_label(provider_id: str) -> str:
    provider = get_provider(provider_id)
    return provider["name"] if provider else provider_id


def flag_host_key_change(provider_id: str, fingerprint: str) -> None:
    """An untrusted Controller host key is a security event: raise a critical alert until an operator approves or revokes it."""
    provider = get_provider(provider_id)
    if not provider:
        return
    try:
        from provider_store import upsert_monitoring_alert
        upsert_monitoring_alert(provider_id, "security:host_key", "critical", f"{provider['name']} SSH 호스트 키 변경 감지",
                                f"VIP {provider['vip']}:{provider['port']}의 SSH 호스트 키 지문이 신뢰 목록과 다릅니다 ({fingerprint}). VIP가 다른 Controller로 이동했거나 서버가 교체된 경우입니다. "
                                "공급자 연결 › SSH 키 관리에서 대상 Controller에서 직접 확인한 지문과 일치할 때만 승인하세요. 승인 전까지 점검과 탐색은 실행되지 않습니다.",
                                provider.get("controller_hostname") or provider["vip"], category="security")
        audit("provider.host_key.changed", "provider", provider_id, provider["name"], fingerprint, outcome="failure")
    except Exception:  # noqa: BLE001
        logger.exception("host key change alert failed for %s", provider_id)

# sudo escalation for non-root SSH accounts (see run_as_root)
SUDO_PROBE_COMMAND = "sudo -k -n true"
SUDO_NOPASSWD_COMMAND = "sudo -n -H bash -s"
SUDO_PASSWORD_COMMAND = "sudo -S -p '' -k -H bash -s"
SUDO_PASSWORD_CHECK_COMMAND = "sudo -S -p '' -k -H true"
ROOT_MARKER = "__OKESTRO_ROOT_SHELL__"

CHECK_KEYS = {
    "cpu", "memory", "disk", "chrony", "bonding", "mount", "pcs", "vip", "rabbitmq", "mysql",
    "mysql_host_blocked_errors", "wsrep_local_cert_failures",
    "endpoint", "nova", "neutron", "cinder", "manila", "octavia", "masakari", "swift", "heat", "nova_compute",
    "vm", "network", "volume", "snapshot", "share", "lb", "amphora", "masakari_notification", "swift_container", "heat_stack",
    "nova_log", "neutron_log", "cinder_log", "glance_log", "manila_log", "octavia_log", "masakari_log", "swift_log", "heat_log", "system_log",
    "virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration",
    "libvirt_state", "instance_storage", "smart_health", "raid_health",
}


class CheckRequest(BaseModel):
    selected_items: list[str] | None = None


class CheckScheduleRequest(BaseModel):
    enabled: bool = False
    run_time: str = Field(default="09:00", pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    selected_items: list[str] | None = None


class HostKeyApprovalRequest(BaseModel):
    fingerprint: str = Field(min_length=16, max_length=255)


class DatabaseCredentialsRequest(BaseModel):
    username: str = Field(min_length=1, max_length=128, pattern=r"^[^\r\n\x00]+$")
    password: str = Field(min_length=1, max_length=1024, pattern=r"^[^\r\n\x00]+$")
    host: str = Field(default="localhost", min_length=1, max_length=253, pattern=r"^[A-Za-z0-9_.:-]+$")
    port: int = Field(default=3306, ge=1, le=65535)


class SudoCredentialsRequest(BaseModel):
    sudo_password: str = Field(min_length=1, max_length=1024, pattern=r"^[^\r\n\x00]+$")


class CheckExceptionRequest(BaseModel):
    item_key: str = Field(min_length=1, max_length=64)
    reason: str = Field(min_length=1, max_length=300)
    node_hostname: str = Field(default="", max_length=253)


ALLOWED_CUSTOM_COMMANDS = {"chronyc", "df", "free", "hostname", "ip", "lsblk", "mount", "openstack", "pcs", "ps", "rabbitmqctl", "ss", "systemctl", "uptime", "virsh"}
FORBIDDEN_CUSTOM_ARGUMENTS = {"add", "create", "delete", "disable", "enable", "evacuate", "flush", "kill", "migrate", "purge", "reboot", "remove", "replace", "restart", "resume", "set", "shutdown", "start", "stop", "suspend", "write"}


def validate_custom_command(command: str) -> list[str]:
    if any(token in command for token in ("\n", "\r", ";", "|", "&", ">", "<", "`", "$(")):
        raise ValueError("파이프, 리다이렉션, 명령 연결 및 명령 치환은 사용할 수 없습니다.")
    try:
        parts = shlex.split(command)
    except ValueError as exc:
        raise ValueError("명령의 따옴표 구문을 확인하세요.") from exc
    if not parts or parts[0] not in ALLOWED_CUSTOM_COMMANDS:
        raise ValueError(f"허용된 읽기 전용 명령만 사용할 수 있습니다: {', '.join(sorted(ALLOWED_CUSTOM_COMMANDS))}")
    if any(part.lower() in FORBIDDEN_CUSTOM_ARGUMENTS for part in parts[1:]):
        raise ValueError("상태를 변경할 수 있는 명령 인수는 사용할 수 없습니다.")
    if parts[0] == "mount" and len(parts) != 1:
        raise ValueError("mount는 현재 마운트 목록 조회만 허용됩니다.")
    return parts


class LogExclusionRequest(BaseModel):
    service: str = Field(default="", max_length=20)
    pattern: str = Field(min_length=1, max_length=300)
    reason: str = Field(min_length=1, max_length=300)


def validate_log_pattern(pattern: str) -> str:
    """Patterns run through Python re (server side) and grep -E (on the node); both must accept them."""
    value = pattern.strip()
    if not value or "\n" in value or "\r" in value:
        raise ValueError("패턴은 한 줄로 입력하세요.")
    try:
        re.compile(value, re.IGNORECASE)
    except re.error as exc:
        raise ValueError(f"정규식 오류: {exc}") from exc
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".re", delete=True) as handle:
            handle.write(value + "\n")
            handle.flush()
            probe = subprocess.run(["grep", "-Eiq", "-f", handle.name], input=b"probe\n", capture_output=True, timeout=5)
        if probe.returncode > 1:
            raise ValueError(f"grep -E가 해석할 수 없는 패턴입니다: {probe.stderr.decode(errors='replace').strip() or '문법 오류'}")
    except (OSError, subprocess.SubprocessError):
        pass  # grep missing on the deploy host: rely on the Python check
    return value


class CustomCheckRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(default="", max_length=500)
    target_role: str = "all"
    command: str = Field(min_length=1, max_length=500)
    execution_context: str = "plain"
    rule_type: str = "exit_code"
    expected_value: str = Field(default="", max_length=200)
    timeout_seconds: int = Field(default=20, ge=5, le=60)
    enabled: bool = True

    @model_validator(mode="after")
    def validate_custom_check(self):
        if self.target_role not in {"all", "controller", "compute", "active_controller"}:
            raise ValueError("지원하지 않는 실행 대상입니다.")
        if self.execution_context not in {"plain", "openstack"}:
            raise ValueError("지원하지 않는 실행 환경입니다.")
        if self.rule_type not in {"exit_code", "contains", "not_contains"}:
            raise ValueError("지원하지 않는 판정 규칙입니다.")
        if self.rule_type != "exit_code" and not self.expected_value.strip():
            raise ValueError("문자열 판정값을 입력하세요.")
        validate_custom_command(self.command)
        return self


class WorkHistoryRequest(BaseModel):
    provider_id: str | None = None
    title: str = Field(min_length=1, max_length=200)
    work_type: str
    status: str
    operator: str = Field(default="", max_length=100)  # blank → the logged-in account (validated_work_history)
    target: str = Field(default="", max_length=300)
    ticket: str = Field(default="", max_length=100)
    description: str = Field(min_length=1, max_length=5000)
    commands: str = Field(default="", max_length=10000)
    before_state: str = Field(default="", max_length=5000)
    after_state: str = Field(default="", max_length=5000)
    result: str = Field(default="", max_length=5000)
    follow_up: str = Field(default="", max_length=5000)
    started_at: datetime
    completed_at: datetime | None = None

    @field_validator("work_type")
    @classmethod
    def validate_work_type(cls, value: str) -> str:
        if value not in {"inspection", "incident", "change", "restart", "deployment", "maintenance", "other"}:
            raise ValueError("지원하지 않는 작업 유형입니다.")
        return value

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        if value not in {"planned", "approved", "in_progress", "completed", "failed"}:
            raise ValueError("지원하지 않는 작업 상태입니다.")
        return value

    @model_validator(mode="after")
    def validate_work_history(self):
        if self.completed_at and self.completed_at < self.started_at:
            raise ValueError("완료 시각은 시작 시각보다 빠를 수 없습니다.")
        return self


class AlertUpdateRequest(BaseModel):
    status: str
    assignee: str = Field(default="", max_length=100)
    resolution_note: str = Field(default="", max_length=2000)
    work_history_id: str | None = None

    @field_validator("status")
    @classmethod
    def validate_alert_status(cls, value: str) -> str:
        if value not in {"open", "acknowledged", "resolved"}:
            raise ValueError("지원하지 않는 알림 상태입니다.")
        return value

    @model_validator(mode="after")
    def validate_resolution(self):
        if self.status == "resolved" and not self.resolution_note.strip():
            raise ValueError("해소 처리 시 조치 내용을 입력하세요.")
        return self


class DiscoveryRequest(BaseModel):
    provider_name: str = Field(default="OpenStack Provider", min_length=1, max_length=100)
    vip: str = Field(min_length=1, max_length=253)
    port: int = Field(default=22, ge=1, le=65535)
    username: str = Field(min_length=1, max_length=64)
    auth_method: str = "private_key"
    private_key: str | None = None
    passphrase: str | None = None
    password: str | None = None
    sudo_password: str | None = Field(default=None, max_length=1024, pattern=r"^[^\r\n\x00]+$")
    trusted_fingerprint: str | None = None

    @field_validator("vip")
    @classmethod
    def validate_vip(cls, value: str) -> str:
        value = value.strip()
        try:
            ipaddress.ip_address(value)
        except ValueError:
            if not re.fullmatch(r"(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?", value):
                raise ValueError("올바른 IP 주소 또는 호스트명을 입력하세요.")
        return value

    @model_validator(mode="after")
    def validate_credentials(self):
        if self.auth_method not in {"private_key", "password"}:
            raise ValueError("지원하지 않는 SSH 인증 방식입니다.")
        if self.auth_method == "private_key" and not self.private_key:
            raise ValueError("SSH 개인키가 필요합니다.")
        if self.auth_method == "password" and not self.password:
            raise ValueError("SSH 비밀번호가 필요합니다.")
        return self


class KeystoneRequest(BaseModel):
    auth_url: str = Field(min_length=8, max_length=2048)
    username: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=1)
    user_domain: str = Field(default="Default", min_length=1, max_length=255)
    project_name: str = Field(min_length=1, max_length=255)
    project_domain: str = Field(default="Default", min_length=1, max_length=255)
    region: str | None = Field(default=None, max_length=255)
    verify_tls: bool = True

    @field_validator("auth_url")
    @classmethod
    def validate_auth_url(cls, value: str) -> str:
        value = value.strip().rstrip("/")
        if not re.match(r"^https?://[^/\s]+(?::\d+)?(?:/.*)?$", value):
            raise ValueError("올바른 Keystone HTTP(S) URL을 입력하세요.")
        return value


@app.get("/api/health")
async def health(request: Request):
    payload = {"status": "ok", "version": app.version, "server_time": datetime.now(timezone.utc).isoformat(), "authenticated": bool(request.state.user)}
    if request.state.user:
        payload.update({
            "timezone": str(schedule_timezone()), "providers": len(list_providers()),
            "running_checks": sum(1 for progress in CHECK_PROGRESS.values() if progress.get("running")),
        })
    return payload


def validated_work_history(request: WorkHistoryRequest) -> dict:
    data = request.model_dump(mode="json")
    for key in ("title", "operator", "target", "ticket", "description", "commands", "before_state", "after_state", "result", "follow_up"):
        data[key] = data[key].strip()
    if not data["operator"]:
        current = CURRENT_REQUEST.get()
        user = getattr(current.state, "user", None) if current else None
        if not user:
            raise HTTPException(400, "작업자를 입력하세요.")
        data["operator"] = user["username"]
    if request.provider_id and not get_provider(request.provider_id):
        raise HTTPException(400, "등록된 공급자를 찾을 수 없습니다.")
    return data


@app.get("/api/work-histories")
async def work_history_list(provider_id: str = "", work_type: str = "", status: str = "", q: str = Query(default="", max_length=200)):
    return {"histories": list_work_histories(provider_id, work_type, status, q.strip())}


@app.post("/api/work-histories", status_code=201)
async def create_work_history(request: WorkHistoryRequest):
    history = save_work_history(validated_work_history(request))
    audit("work_history.create", "work_history", history["id"], history["title"], f"{history.get('work_type', '')} · {history.get('status', '')}")
    return history


@app.get("/api/work-histories/{history_id}")
async def work_history_detail(history_id: str):
    history = get_work_history(history_id)
    if not history:
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    return history


@app.put("/api/work-histories/{history_id}")
async def edit_work_history(history_id: str, request: WorkHistoryRequest):
    history = update_work_history(history_id, validated_work_history(request))
    if not history:
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    audit("work_history.update", "work_history", history_id, history["title"], f"{history.get('work_type', '')} · {history.get('status', '')}")
    return history


@app.delete("/api/work-histories/{history_id}")
async def remove_work_history(history_id: str):
    existing = get_work_history(history_id)
    if not delete_work_history(history_id):
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    audit("work_history.delete", "work_history", history_id, existing["title"] if existing else history_id)
    return {"status": "deleted"}


# --- Work history extensions ---
# Approval flow (예정 → 승인 → 진행 중 → 완료/실패), before/after inspections, attachments and the monthly CSV report.
import csv
import io

WORK_STATUS_LABELS = {"planned": "예정", "approved": "승인", "in_progress": "진행 중", "completed": "완료", "failed": "실패"}
WORK_TYPE_LABELS = {"inspection": "점검", "incident": "장애 대응", "change": "설정 변경", "restart": "재시작", "deployment": "배포", "maintenance": "유지보수", "other": "기타"}
MAX_WORK_ATTACHMENTS = 10
MAX_WORK_ATTACHMENT_BYTES = 10 * 1024 * 1024


class WorkTransitionRequest(BaseModel):
    status: str = Field(min_length=1, max_length=20)


class WorkHistoryCheckRequest(BaseModel):
    selected_items: list[str] | None = None


class WorkHistoryCheckLinkRequest(BaseModel):
    before_check_id: str | None = None
    after_check_id: str | None = None


def work_history_or_404(history_id: str) -> dict:
    history = get_work_history(history_id)
    if not history:
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    return history


@app.post("/api/work-histories/{history_id}/transition")
async def transition_work_history_status(history_id: str, payload: WorkTransitionRequest, request: Request):
    if payload.status not in WORK_TRANSITIONS:
        raise HTTPException(400, "지원하지 않는 작업 상태입니다.")
    actor = request.state.user["username"] if request.state.user else ""
    try:
        history = transition_work_history(history_id, payload.status, actor)
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    if not history:
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    audit("work_history.transition", "work_history", history_id, history["title"], f"→ {WORK_STATUS_LABELS.get(payload.status, payload.status)}" + (f" · 승인자 {actor}" if payload.status == "approved" else ""))
    return history


@app.post("/api/work-histories/{history_id}/checks/{phase}")
async def run_work_history_check(history_id: str, phase: str, payload: WorkHistoryCheckRequest | None = None):
    """Start a 작업 전/후 inspection for the history's provider in the background; the client follows /checks/progress."""
    if phase not in {"before", "after"}:
        raise HTTPException(400, "phase는 before 또는 after여야 합니다.")
    history = work_history_or_404(history_id)
    provider_id = history.get("provider_id")
    if not provider_id or not get_provider(provider_id):
        raise HTTPException(400, "공급자가 지정된 작업 이력만 전후 점검을 실행할 수 있습니다.")
    if CHECK_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "이미 이 공급자의 일일점검이 실행 중입니다. 완료 후 다시 실행하세요.")
    if not list_provider_nodes(provider_id):
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
    selected = payload.selected_items if payload and payload.selected_items else None
    label = "작업 전" if phase == "before" else "작업 후"

    async def runner():
        try:
            result = await run_provider_check(provider_id, CheckRequest(selected_items=selected), trigger="manual")
            set_work_history_check(history_id, phase, result["check_id"])
            audit("work_history.check", "work_history", history_id, history["title"], f"{label} 점검 완료 · {result.get('status')} · 점검 ID {result['check_id']}")
        except HTTPException as exc:
            audit("work_history.check", "work_history", history_id, history["title"], f"{label} 점검 실패 · {exc.detail}", outcome="failure")
        except Exception as exc:  # noqa: BLE001 - background task must not die silently
            logger.exception("work history %s check failed", history_id)
            audit("work_history.check", "work_history", history_id, history["title"], f"{label} 점검 실패 · {type(exc).__name__}", outcome="failure")

    task = asyncio.create_task(runner())
    BACKGROUND_TASKS.add(task)
    task.add_done_callback(BACKGROUND_TASKS.discard)
    audit("work_history.check", "work_history", history_id, history["title"], f"{label} 점검 시작 · 항목 {len(selected) if selected else '전체'}")
    return {"status": "started", "phase": phase, "provider_id": provider_id}


@app.put("/api/work-histories/{history_id}/checks")
async def link_work_history_checks(history_id: str, payload: WorkHistoryCheckLinkRequest):
    history = work_history_or_404(history_id)
    provider_id = history.get("provider_id")
    for phase, check_id in (("before", payload.before_check_id), ("after", payload.after_check_id)):
        if check_id and (not provider_id or not check_summary(provider_id, check_id)):
            raise HTTPException(400, f"{'작업 전' if phase == 'before' else '작업 후'} 점검 결과가 이 공급자의 이력에 없습니다.")
        history = set_work_history_check(history_id, phase, check_id or None)
    audit("work_history.check", "work_history", history_id, history["title"], f"점검 연결 · 전 {payload.before_check_id or '-'} · 후 {payload.after_check_id or '-'}")
    return history


@app.get("/api/work-histories/{history_id}/comparison")
async def work_history_comparison(history_id: str):
    history = work_history_or_404(history_id)
    provider_id = history.get("provider_id")
    before = check_summary(provider_id, history["before_check_id"]) if provider_id and history.get("before_check_id") else None
    after = check_summary(provider_id, history["after_check_id"]) if provider_id and history.get("after_check_id") else None
    brief = lambda check: {"id": check["id"], "checked_at": check["checked_at"], "status": check["status"], "items": check["summary"]["items"], "nodes": check["summary"]["nodes"]} if check else None  # noqa: E731
    diff = build_check_diff(after, before) if before and after else None
    return {"history_id": history_id, "provider_id": provider_id, "before": brief(before), "after": brief(after), "diff": diff,
            "running": bool(provider_id and CHECK_PROGRESS.get(provider_id, {}).get("running"))}


@app.get("/api/work-histories/{history_id}/attachments")
async def work_history_attachments(history_id: str):
    work_history_or_404(history_id)
    return {"attachments": list_work_history_attachments(history_id), "max_files": MAX_WORK_ATTACHMENTS, "max_bytes": MAX_WORK_ATTACHMENT_BYTES}


@app.post("/api/work-histories/{history_id}/attachments", status_code=201)
async def upload_work_history_attachment(history_id: str, request: Request, file: UploadFile = File(...)):
    history = work_history_or_404(history_id)
    if len(list_work_history_attachments(history_id)) >= MAX_WORK_ATTACHMENTS:
        raise HTTPException(400, f"첨부 파일은 작업당 최대 {MAX_WORK_ATTACHMENTS}개까지 저장할 수 있습니다.")
    filename = Path(file.filename or "").name.strip() or "attachment"
    data = await file.read(MAX_WORK_ATTACHMENT_BYTES + 1)
    if len(data) > MAX_WORK_ATTACHMENT_BYTES:
        raise HTTPException(413, "첨부 파일은 10 MB 이하여야 합니다.")
    if not data:
        raise HTTPException(400, "빈 파일은 첨부할 수 없습니다.")
    actor = request.state.user["username"] if request.state.user else ""
    attachment = add_work_history_attachment(history_id, filename, file.content_type or "", data, actor)
    audit("work_history.attachment.add", "work_history", history_id, history["title"], f"{filename} · {len(data)} bytes")
    return attachment


@app.get("/api/work-histories/{history_id}/attachments/{attachment_id}")
async def download_work_history_attachment(history_id: str, attachment_id: str):
    work_history_or_404(history_id)
    attachment = get_work_history_attachment(history_id, attachment_id)
    if not attachment or not attachment["path"].is_file():
        raise HTTPException(404, "첨부 파일을 찾을 수 없습니다.")
    return FileResponse(attachment["path"], media_type=attachment["content_type"] or "application/octet-stream", filename=attachment["filename"],
                        headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"})


@app.delete("/api/work-histories/{history_id}/attachments/{attachment_id}")
async def remove_work_history_attachment(history_id: str, attachment_id: str):
    history = work_history_or_404(history_id)
    attachment = delete_work_history_attachment(history_id, attachment_id)
    if not attachment:
        raise HTTPException(404, "첨부 파일을 찾을 수 없습니다.")
    audit("work_history.attachment.delete", "work_history", history_id, history["title"], attachment["filename"])
    return {"status": "deleted"}


@app.get("/api/work-history-reports/monthly.csv")
async def export_work_histories_csv(month: str = Query(..., pattern=r"^\d{4}-(0[1-9]|1[0-2])$"), provider_id: str = ""):
    """Monthly work report: UTF-8 with BOM so Excel opens the Korean text directly."""
    tz = schedule_timezone()
    # started_at/completed_at are stored as pydantic JSON ("...Z"), which Python 3.10's fromisoformat does not accept.
    local = lambda value: datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(tz).strftime("%Y-%m-%d %H:%M") if value else ""  # noqa: E731
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["시작 시각", "완료 시각", "공급자", "제목", "작업 유형", "상태", "작업자", "승인자", "승인 시각", "대상", "티켓", "작업 목적 및 내용", "결과 및 검증", "후속 조치", "작업 전 점검", "작업 후 점검"])
    rows = list_work_histories_for_month(month, provider_id.strip())
    for item in rows:
        writer.writerow([local(item["started_at"]), local(item.get("completed_at")), item.get("provider_name") or "공통", item["title"], WORK_TYPE_LABELS.get(item["work_type"], item["work_type"]),
                         WORK_STATUS_LABELS.get(item["status"], item["status"]), item["operator"], item.get("approved_by") or "", local(item.get("approved_at")), item.get("target", ""),
                         item.get("ticket", ""), item["description"], item.get("result", ""), item.get("follow_up", ""), item.get("before_check_id") or "", item.get("after_check_id") or ""])
    audit("work_history.export", "work_history", "", f"{month} 월간 보고서", f"{len(rows)}건" + (f" · 공급자 {provider_label(provider_id.strip())}" if provider_id.strip() else ""))
    content = "﻿" + buffer.getvalue()
    return Response(content=content.encode("utf-8"), media_type="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f"attachment; filename=work-history-{month}.csv; filename*=UTF-8''{quote(f'작업이력_{month}.csv')}", "Cache-Control": "no-store"})


# --- Alerts extensions ---
def current_actor() -> str:
    request = CURRENT_REQUEST.get()
    user = getattr(request.state, "user", None) if request else None
    return user["username"] if user else "system"


# --- Issue notes ---------------------------------------------------------------------------------
# A Confluence-style page per issue: Markdown body, code snippets with file path and language, and a
# timeline of comments and status changes. Issues link to alerts, work histories and check results.
ISSUE_STATUS_LABELS = {"open": "열림", "in_progress": "진행 중", "on_hold": "보류", "resolved": "해결"}
ISSUE_SEVERITY_LABELS = {"critical": "치명", "high": "높음", "medium": "보통", "low": "낮음"}
ISSUE_CATEGORY_LABELS = {"incident": "장애", "bug": "결함", "config": "설정", "performance": "성능", "capacity": "용량", "question": "확인 요청", "improvement": "개선", "other": "기타"}


class IssueRequest(BaseModel):
    provider_id: str | None = None
    title: str = Field(min_length=1, max_length=200)
    status: str = "open"
    severity: str = "medium"
    category: str = "other"
    tags: list[str] = Field(default_factory=list, max_length=20)
    body: str = Field(default="", max_length=60000)
    assignee: str = Field(default="", max_length=100)
    target: str = Field(default="", max_length=300)
    resolution: str = Field(default="", max_length=5000)
    alert_id: str | None = Field(default=None, max_length=64)
    work_history_id: str | None = Field(default=None, max_length=64)
    check_id: str | None = Field(default=None, max_length=64)

    @field_validator("status")
    @classmethod
    def validate_issue_status(cls, value: str) -> str:
        if value not in ISSUE_STATUSES:
            raise ValueError("지원하지 않는 이슈 상태입니다.")
        return value

    @field_validator("severity")
    @classmethod
    def validate_issue_severity(cls, value: str) -> str:
        if value not in ISSUE_SEVERITIES:
            raise ValueError("지원하지 않는 심각도입니다.")
        return value

    @field_validator("category")
    @classmethod
    def validate_issue_category(cls, value: str) -> str:
        if value not in ISSUE_CATEGORIES:
            raise ValueError("지원하지 않는 분류입니다.")
        return value

    @field_validator("tags")
    @classmethod
    def validate_issue_tags(cls, value: list[str]) -> list[str]:
        return [str(tag).strip()[:40] for tag in value if str(tag).strip()]


class IssueTransitionRequest(BaseModel):
    status: str
    note: str = Field(default="", max_length=5000)


class IssueSnippetRequest(BaseModel):
    title: str = Field(default="", max_length=200)
    path: str = Field(default="", max_length=300)
    language: str = "text"
    code: str = Field(min_length=1, max_length=200000)

    @field_validator("language")
    @classmethod
    def validate_language(cls, value: str) -> str:
        if value not in ISSUE_LANGUAGES:
            raise ValueError("지원하지 않는 언어입니다.")
        return value


class IssueCommentRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


def issue_or_404(issue_id: str) -> dict:
    issue = get_issue(issue_id)
    if not issue:
        raise HTTPException(404, "이슈를 찾을 수 없습니다.")
    return issue


def validated_issue(request: IssueRequest) -> dict:
    data = request.model_dump(mode="json")
    for key in ("title", "body", "assignee", "target", "resolution"):
        data[key] = data[key].strip()
    if not data["title"]:
        raise HTTPException(400, "제목을 입력하세요.")
    if data["provider_id"] and not get_provider(data["provider_id"]):
        raise HTTPException(400, "등록된 공급자를 찾을 수 없습니다.")
    if data["alert_id"] and not store_get_alert(data["alert_id"]):
        raise HTTPException(400, "연결할 알림을 찾을 수 없습니다.")
    if data["work_history_id"] and not get_work_history(data["work_history_id"]):
        raise HTTPException(400, "연결할 작업 이력을 찾을 수 없습니다.")
    if data["check_id"]:
        if not data["provider_id"] or not store_get_check(data["provider_id"], data["check_id"]):
            raise HTTPException(400, "연결할 점검 결과를 찾을 수 없습니다. 공급자와 점검 ID를 확인하세요.")
    return data


def issue_detail_payload(issue: dict) -> dict:
    """Detail view: the issue with its snippets, timeline and the linked records' short summaries."""
    detail = dict(issue)
    detail["snippets"] = list_issue_snippets(issue["id"])
    detail["events"] = list_issue_events(issue["id"])
    links = {}
    if issue.get("alert_id"):
        alert = store_get_alert(issue["alert_id"])
        links["alert"] = {"id": alert["id"], "title": alert["title"], "status": alert["status"], "severity": alert["severity"]} if alert else None
    if issue.get("work_history_id"):
        history = get_work_history(issue["work_history_id"])
        links["work_history"] = {"id": history["id"], "title": history["title"], "status": history["status"], "work_type": history["work_type"]} if history else None
    if issue.get("check_id") and issue.get("provider_id"):
        check = store_get_check(issue["provider_id"], issue["check_id"])
        links["check"] = {"id": check["id"], "status": check.get("status"), "created_at": check.get("created_at")} if check else None
    detail["links"] = links
    return detail


@app.get("/api/issues/meta")
async def issue_meta():
    return {"statuses": [{"key": key, "label": ISSUE_STATUS_LABELS[key]} for key in ISSUE_STATUSES],
            "severities": [{"key": key, "label": ISSUE_SEVERITY_LABELS[key]} for key in ISSUE_SEVERITIES],
            "categories": [{"key": key, "label": ISSUE_CATEGORY_LABELS[key]} for key in ISSUE_CATEGORIES],
            "languages": list(ISSUE_LANGUAGES), "transitions": {key: sorted(value) for key, value in ISSUE_TRANSITIONS.items()}}


@app.get("/api/issues/summary")
async def issue_summary_view():
    return issue_summary()


@app.get("/api/issues")
async def issue_list(provider_id: str = "", status: str = "", severity: str = "", category: str = "", tag: str = Query(default="", max_length=40),
                     q: str = Query(default="", max_length=200), alert_id: str = "", work_history_id: str = "", check_id: str = ""):
    return {"issues": list_issues(provider_id, status, severity, category, tag.strip(), q.strip(), alert_id, work_history_id, check_id)}


@app.post("/api/issues", status_code=201)
async def create_issue(request: IssueRequest):
    issue = save_issue(validated_issue(request), current_actor())
    audit("issue.create", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"{ISSUE_SEVERITY_LABELS[issue['severity']]} · {ISSUE_CATEGORY_LABELS[issue['category']]}")
    return issue_detail_payload(issue)


@app.get("/api/issues/{issue_id}")
async def issue_detail(issue_id: str):
    return issue_detail_payload(issue_or_404(issue_id))


@app.put("/api/issues/{issue_id}")
async def edit_issue(issue_id: str, request: IssueRequest):
    existing = issue_or_404(issue_id)
    issue = update_issue(existing["id"], validated_issue(request), current_actor())
    audit("issue.update", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"{ISSUE_STATUS_LABELS[issue['status']]} · {ISSUE_SEVERITY_LABELS[issue['severity']]}")
    return issue_detail_payload(issue)


@app.delete("/api/issues/{issue_id}")
async def remove_issue(issue_id: str):
    existing = issue_or_404(issue_id)
    delete_issue(existing["id"])
    audit("issue.delete", "issue", existing["id"], f"{existing['key']} {existing['title']}")
    return {"deleted": True}


@app.post("/api/issues/{issue_id}/transition")
async def transition_issue_status(issue_id: str, payload: IssueTransitionRequest):
    existing = issue_or_404(issue_id)
    if payload.status not in ISSUE_STATUSES:
        raise HTTPException(400, "지원하지 않는 이슈 상태입니다.")
    try:
        issue = transition_issue(existing["id"], payload.status, current_actor(), payload.note.strip())
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    audit("issue.transition", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"→ {ISSUE_STATUS_LABELS[payload.status]}")
    return issue_detail_payload(issue)


@app.get("/api/issues/{issue_id}/events")
async def issue_events(issue_id: str):
    issue = issue_or_404(issue_id)
    return {"events": list_issue_events(issue["id"])}


@app.post("/api/issues/{issue_id}/comments", status_code=201)
async def comment_issue(issue_id: str, payload: IssueCommentRequest):
    issue = issue_or_404(issue_id)
    event = add_issue_comment(issue["id"], payload.text.strip(), current_actor())
    audit("issue.comment", "issue", issue["id"], f"{issue['key']} {issue['title']}", payload.text.strip()[:200])
    return event


@app.get("/api/issues/{issue_id}/snippets")
async def issue_snippets(issue_id: str):
    issue = issue_or_404(issue_id)
    return {"snippets": list_issue_snippets(issue["id"])}


@app.post("/api/issues/{issue_id}/snippets", status_code=201)
async def create_issue_snippet(issue_id: str, payload: IssueSnippetRequest):
    issue = issue_or_404(issue_id)
    data = payload.model_dump()
    data["title"], data["path"] = data["title"].strip(), data["path"].strip()
    snippet = add_issue_snippet(issue["id"], data, current_actor())
    audit("issue.snippet.add", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"{data['language']} · {data['path'] or data['title'] or '-'}")
    return snippet


@app.put("/api/issues/{issue_id}/snippets/{snippet_id}")
async def edit_issue_snippet(issue_id: str, snippet_id: str, payload: IssueSnippetRequest):
    issue = issue_or_404(issue_id)
    data = payload.model_dump()
    data["title"], data["path"] = data["title"].strip(), data["path"].strip()
    snippet = update_issue_snippet(issue["id"], snippet_id, data, current_actor())
    if not snippet:
        raise HTTPException(404, "코드 스니펫을 찾을 수 없습니다.")
    audit("issue.snippet.update", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"{data['language']} · {data['path'] or data['title'] or '-'}")
    return snippet


@app.delete("/api/issues/{issue_id}/snippets/{snippet_id}")
async def remove_issue_snippet(issue_id: str, snippet_id: str):
    issue = issue_or_404(issue_id)
    snippet = delete_issue_snippet(issue["id"], snippet_id, current_actor())
    if not snippet:
        raise HTTPException(404, "코드 스니펫을 찾을 수 없습니다.")
    audit("issue.snippet.delete", "issue", issue["id"], f"{issue['key']} {issue['title']}", f"{snippet['language']} · {snippet['path'] or snippet['title'] or '-'}")
    return {"deleted": True}


def issue_markdown_document(detail: dict) -> str:
    """Markdown export that pastes cleanly into Confluence, GitLab or a wiki."""
    lines = [f"# {detail['key']} {detail['title']}", ""]
    lines.append(f"- 상태: {ISSUE_STATUS_LABELS.get(detail['status'], detail['status'])} · 심각도: {ISSUE_SEVERITY_LABELS.get(detail['severity'], detail['severity'])} · 분류: {ISSUE_CATEGORY_LABELS.get(detail['category'], detail['category'])}")
    lines.append(f"- 공급자: {detail.get('provider_name') or '공통'} · 대상: {detail.get('target') or '-'} · 담당: {detail.get('assignee') or '-'} · 등록: {detail.get('reporter') or '-'}")
    if detail.get("tags"):
        lines.append("- 태그: " + ", ".join(f"#{tag}" for tag in detail["tags"]))
    lines.append(f"- 등록 {detail['created_at'][:16].replace('T', ' ')} UTC · 수정 {detail['updated_at'][:16].replace('T', ' ')} UTC" + (f" · 해결 {detail['resolved_at'][:16].replace('T', ' ')} UTC" if detail.get("resolved_at") else ""))
    links = detail.get("links") or {}
    if any(links.values()):
        lines.append("")
        lines.append("## 연결")
        if links.get("alert"):
            lines.append(f"- 알림: {links['alert']['title']} ({links['alert']['status']})")
        if links.get("work_history"):
            lines.append(f"- 작업 이력: {links['work_history']['title']} ({links['work_history']['status']})")
        if links.get("check"):
            lines.append(f"- 점검 결과: {links['check']['id']} ({links['check'].get('status') or '-'})")
    lines += ["", "## 내용", "", detail.get("body") or "(내용 없음)"]
    if detail.get("resolution"):
        lines += ["", "## 해결 내용", "", detail["resolution"]]
    if detail.get("snippets"):
        lines += ["", "## 코드"]
        for snippet in detail["snippets"]:
            heading = " · ".join(part for part in (snippet.get("title"), snippet.get("path")) if part) or snippet.get("language", "text")
            fence = "````" if "```" in snippet["code"] else "```"
            lines += ["", f"### {heading}", "", f"{fence}{snippet.get('language', 'text')}", snippet["code"].rstrip("\n"), fence]
    if detail.get("events"):
        lines += ["", "## 타임라인", ""]
        for event in reversed(detail["events"]):
            lines.append(f"- {event['created_at'][:16].replace('T', ' ')} UTC · {event.get('actor') or 'system'} · {event['kind']}: {event.get('text') or '-'}")
    return "\n".join(lines) + "\n"


@app.get("/api/issues/{issue_id}/export")
async def export_issue(issue_id: str):
    detail = issue_detail_payload(issue_or_404(issue_id))
    audit("issue.export", "issue", detail["id"], f"{detail['key']} {detail['title']}")
    filename = f"{detail['key']}.md"
    return Response(content=issue_markdown_document(detail).encode("utf-8"), media_type="text/markdown; charset=utf-8",
                    headers={"Content-Disposition": f"attachment; filename={filename}; filename*=UTF-8''{quote(filename)}", "Cache-Control": "no-store"})


CONTROLLER_FAILURE_MARKERS = ("활성 Controller SSH 연결 실패", "활성 Controller root 권한 획득 실패", "SSH 접속 후 OpenStack 명령 실행이", "활성 Controller 연결 실패")
ALERT_SERVICE_FAMILIES = {
    "Nova": {"nova", "nova_log", "nova_compute", "vm", "libvirt_state", "kvm_acceleration", "instance_storage"},
    "Neutron": {"neutron", "neutron_log", "network", "ovs_state"},
    "Cinder": {"cinder", "cinder_log", "volume", "snapshot"},
    "Glance": {"glance_log"},
    "Manila": {"manila", "manila_log", "share"},
    "Octavia": {"octavia", "octavia_log", "lb", "amphora"},
    "Masakari": {"masakari", "masakari_log", "masakari_notification"},
    "Swift": {"swift", "swift_log", "swift_container"},
    "Heat": {"heat", "heat_log", "heat_stack"},
    "MySQL": {"mysql", "mysql_host_blocked_errors", "wsrep_local_cert_failures"},
    "클러스터": {"pcs", "vip", "rabbitmq", "endpoint"},
    "하드웨어": {"smart_health", "raid_health", "bonding", "nic_state", "kernel_errors"},
    "시스템": {"cpu", "memory", "disk", "chrony", "mount", "failed_units", "system_log", "virtualization"},
}
SEVERITY_RANK = {"critical": 0, "warning": 1, "info": 2}


def group_alerts(alerts: list[dict]) -> list[dict]:
    """Fold alerts with one likely root cause into a group: controller-connection failures, one node, one service family."""
    groups: dict[str, dict] = {}
    for alert in alerts:
        item_key = (alert.get("source_key") or "").split(":", 1)[-1]
        provider = alert.get("provider_id") or ""
        provider_name = alert.get("provider_name") or "공통"
        hosts = [part.strip() for part in (alert.get("target") or "").split(",") if part.strip()]
        description = alert.get("description") or ""
        if any(marker in description for marker in CONTROLLER_FAILURE_MARKERS):
            key, title, kind = f"controller:{provider}", f"{provider_name} · 활성 Controller 연결 실패", "controller"
        elif len(hosts) == 1:
            key, title, kind = f"node:{provider}:{hosts[0]}", f"{provider_name} · {hosts[0]} 노드", "node"
        else:
            family = next((name for name, keys in ALERT_SERVICE_FAMILIES.items() if item_key in keys), None)
            if family:
                key, title, kind = f"service:{provider}:{family}", f"{provider_name} · {family} 계열", "service"
            else:
                key, title, kind = f"single:{alert['id']}", alert.get("title") or item_key, "single"
        group = groups.setdefault(key, {"key": key, "kind": kind, "title": title, "provider_id": provider or None, "provider_name": provider_name,
                                        "severity": alert.get("severity"), "count": 0, "open": 0, "acknowledged": 0, "resolved": 0, "suppressed": 0,
                                        "alert_ids": [], "alerts": [], "first_detected_at": alert.get("first_detected_at"), "last_detected_at": alert.get("last_detected_at"),
                                        "cause": description[:200] if kind == "controller" else ""})
        group["count"] += 1
        group[alert.get("status", "open")] = group.get(alert.get("status", "open"), 0) + 1
        if alert.get("suppressed"):
            group["suppressed"] += 1
        group["alert_ids"].append(alert["id"])
        group["alerts"].append(alert)
        if SEVERITY_RANK.get(alert.get("severity"), 9) < SEVERITY_RANK.get(group["severity"], 9):
            group["severity"] = alert.get("severity")
        if (alert.get("first_detected_at") or "") < (group["first_detected_at"] or "~"):
            group["first_detected_at"] = alert.get("first_detected_at")
        if (alert.get("last_detected_at") or "") > (group["last_detected_at"] or ""):
            group["last_detected_at"] = alert.get("last_detected_at")
    ordered = sorted(groups.values(), key=lambda group: (group["open"] + group["acknowledged"] == 0, SEVERITY_RANK.get(group["severity"], 9), -group["count"], group["last_detected_at"] or ""), reverse=False)
    for group in ordered:
        if group["kind"] != "single" and group["count"] == 1:
            group["kind"] = "single"
            group["title"] = group["alerts"][0].get("title") or group["title"]
    return ordered


class AlertBulkRequest(BaseModel):
    ids: list[str] = Field(min_length=1, max_length=500)
    status: str
    assignee: str = Field(default="", max_length=100)
    resolution_note: str = Field(default="", max_length=2000)

    @field_validator("status")
    @classmethod
    def _bulk_status(cls, value: str) -> str:
        if value not in {"open", "acknowledged", "resolved"}:
            raise ValueError("허용되지 않는 처리 상태입니다.")
        return value


class AlertCommentRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class MaintenanceWindowRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    provider_id: str | None = None
    starts_at: str
    ends_at: str
    nodes: list[str] = Field(default_factory=list, max_length=200)
    item_keys: list[str] = Field(default_factory=list, max_length=200)
    work_history_id: str | None = None
    note: str = Field(default="", max_length=2000)


def parse_window_time(value: str, label: str) -> str:
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(400, f"{label} 시각 형식이 올바르지 않습니다.") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=schedule_timezone())
    return parsed.astimezone(timezone.utc).isoformat()


@app.get("/api/alerts/groups")
async def alert_groups(provider_id: str = "", status: str = "", severity: str = "", q: str = Query(default="", max_length=200)):
    alerts = list_alerts(provider_id, status, severity, q.strip())
    return {"groups": group_alerts(alerts), "summary": alert_summary(), "total": len(alerts)}


@app.get("/api/alerts/stats")
async def get_alert_stats(days: int = Query(30, ge=1, le=365)):
    return alert_stats(days)


@app.post("/api/alerts/bulk")
async def bulk_alerts(payload: AlertBulkRequest):
    if payload.status == "resolved" and not payload.resolution_note.strip():
        raise HTTPException(400, "해소 처리에는 조치 내용이 필요합니다.")
    updated = bulk_update_alerts(payload.ids, payload.status, payload.assignee.strip(), payload.resolution_note.strip(), current_actor())
    if not updated:
        raise HTTPException(404, "처리할 알림을 찾을 수 없습니다.")
    audit("alert.bulk", "alert", "", f"알림 {len(updated)}건", f"상태 {payload.status} · 담당 {payload.assignee.strip() or '-'} · {', '.join(item.get('title', '') for item in updated[:5])[:300]}")
    return {"updated": len(updated), "alerts": updated, "summary": alert_summary()}


@app.get("/api/alerts/{alert_id}/events")
async def get_alert_events(alert_id: str):
    alert = get_alert(alert_id)
    if not alert:
        raise HTTPException(404, "알림을 찾을 수 없습니다.")
    return {"alert_id": alert_id, "events": list_alert_events(alert_id)}


@app.post("/api/alerts/{alert_id}/comments", status_code=201)
async def add_comment(alert_id: str, payload: AlertCommentRequest):
    event = add_alert_comment(alert_id, payload.text.strip(), current_actor())
    if not event:
        raise HTTPException(404, "알림을 찾을 수 없습니다.")
    audit("alert.comment", "alert", alert_id, (get_alert(alert_id) or {}).get("title", alert_id), payload.text.strip()[:300])
    return event


@app.get("/api/maintenance-windows")
async def maintenance_window_list(provider_id: str = "", state: str = ""):
    return {"windows": list_maintenance_windows(provider_id, state)}


@app.post("/api/maintenance-windows", status_code=201)
async def create_maintenance_window(payload: MaintenanceWindowRequest):
    if payload.provider_id and not get_provider(payload.provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if payload.work_history_id and not get_work_history(payload.work_history_id):
        raise HTTPException(400, "연결할 작업 이력을 찾을 수 없습니다.")
    starts_at = parse_window_time(payload.starts_at, "시작")
    ends_at = parse_window_time(payload.ends_at, "종료")
    if ends_at <= starts_at:
        raise HTTPException(400, "종료 시각은 시작 시각보다 늦어야 합니다.")
    if payload.nodes and not payload.provider_id:
        raise HTTPException(400, "노드를 지정하려면 공급자를 선택하세요.")
    if payload.provider_id and payload.nodes:
        known = {node["hostname"] for node in list_provider_nodes(payload.provider_id)}
        unknown = [node for node in payload.nodes if node not in known]
        if unknown:
            raise HTTPException(400, f"해당 공급자에 등록되지 않은 노드입니다: {', '.join(unknown[:5])}")
    custom_keys = {item["key"] for item in list_custom_checks(payload.provider_id)} if payload.provider_id else set()
    invalid = [key for key in payload.item_keys if key not in CHECK_KEYS | custom_keys]
    if invalid:
        raise HTTPException(400, f"지원하지 않는 점검 항목: {', '.join(invalid[:5])}")
    window = save_maintenance_window({"title": payload.title.strip(), "provider_id": payload.provider_id, "starts_at": starts_at, "ends_at": ends_at,
                                      "nodes": payload.nodes, "item_keys": payload.item_keys, "work_history_id": payload.work_history_id, "note": payload.note.strip()}, current_actor())
    audit("maintenance.create", "maintenance_window", window["id"], window["title"],
          f"{window.get('provider_name') or '전체 공급자'} · {starts_at[:16]}~{ends_at[:16]} UTC · 노드 {', '.join(payload.nodes) or '전체'} · 항목 {len(payload.item_keys) or '전체'}")
    return window


@app.delete("/api/maintenance-windows/{window_id}")
async def remove_maintenance_window(window_id: str):
    window = delete_maintenance_window(window_id, current_actor())
    if not window:
        raise HTTPException(404, "정비 시간 창을 찾을 수 없습니다.")
    audit("maintenance.delete", "maintenance_window", window_id, window["title"], f"{window.get('provider_name') or '전체 공급자'} · {window['state']}")
    return {"status": "deleted", "window": window}


@app.get("/api/runbooks/{item_key}")
async def get_runbook(item_key: str, provider_id: str = ""):
    overrides = provider_setting(provider_id, "runbooks") if provider_id and get_provider(provider_id) else {}
    runbook = effective_runbook(item_key.split(":", 1)[-1], overrides if isinstance(overrides, dict) else {})
    return {**runbook, "provider_id": provider_id or None, "editable": bool(provider_id)}


@app.get("/api/alerts")
async def alert_list(provider_id: str = "", status: str = "", severity: str = "", q: str = Query(default="", max_length=200)):
    return {"alerts": list_alerts(provider_id, status, severity, q.strip()), "summary": alert_summary()}


@app.get("/api/alerts/summary")
async def get_alert_summary():
    return alert_summary()


@app.get("/api/alerts/{alert_id}")
async def alert_detail(alert_id: str):
    alert = get_alert(alert_id)
    if not alert:
        raise HTTPException(404, "알림을 찾을 수 없습니다.")
    return alert


@app.put("/api/alerts/{alert_id}")
async def edit_alert(alert_id: str, request: AlertUpdateRequest):
    if request.work_history_id and not get_work_history(request.work_history_id):
        raise HTTPException(400, "연결할 작업 이력을 찾을 수 없습니다.")
    alert = update_alert(alert_id, request.status, request.assignee.strip(), request.resolution_note.strip(), request.work_history_id, current_actor())
    if not alert:
        raise HTTPException(404, "알림을 찾을 수 없습니다.")
    audit("alert.update", "alert", alert_id, alert.get("title", alert_id), f"상태 {request.status} · 담당 {request.assignee.strip() or '-'}" + (f" · 작업 이력 {request.work_history_id}" if request.work_history_id else ""))
    return alert


@app.on_event("startup")
async def backfill_latest_check_alerts():
    for provider in list_providers():
        check = latest_check(provider["id"])
        if check:
            sync_check_alerts(provider["id"], check["id"], check["result"].get("items", {}))


async def scan_ssh_host_key(host: str, port: int):
    try:
        key = await asyncio.wait_for(asyncssh.get_server_host_key(host, port=port, config=None), timeout=10)
    except TimeoutError as exc:
        raise HTTPException(504, "SSH 호스트 키 조회 시간이 초과되었습니다.") from exc
    except (asyncssh.Error, OSError) as exc:
        raise HTTPException(502, f"SSH 호스트 키를 조회할 수 없습니다: {type(exc).__name__}") from exc
    if key is None:
        raise HTTPException(502, "SSH 서버가 호스트 키를 제공하지 않았습니다.")
    return key, key.get_fingerprint("sha256")


def trusted_known_hosts(host_key):
    """Build AsyncSSH's in-memory known_hosts tuple with one trusted host key."""
    return known_hosts_of(host_key)


def known_hosts_of(*host_keys):
    """AsyncSSH's in-memory known_hosts tuple trusting exactly these keys.

    With no keys this rejects every host, which is the point: an empty tuple `()` or `None` means
    "skip host key checking" to asyncssh, so the natural-looking empty value is the unsafe one.
    """
    return (list(host_keys), [], [], [], [], [], [])


LEGACY_KNOWN_HOSTS = Path("/root/.ssh/known_hosts")


def provider_known_hosts(provider_id: str):
    """Host key verification for node connections.

    The keys are collected from the active controller during cluster discovery and stored per
    provider, so verification does not depend on a `known_hosts` file on the machine running this
    platform. That file does not exist in a container, and on a freshly built deploy server it is
    empty until somebody runs `ssh-keyscan` against every node by hand.

    Providers discovered before this change have no stored keys yet. For them we fall back to the
    deploy server's file if it happens to exist, so an existing installation keeps working until
    the next discovery fills the table in. Where neither is available the connection fails and
    `node_failure_reason` tells the operator to run discovery again - it never falls back to
    connecting without verification. That last part needs care: asyncssh reads `None` and an empty
    tuple alike as "no host key checking", so the rejecting value is an empty *seven-element*
    tuple, which `known_hosts_of()` builds.
    """
    material = provider_host_key_material(provider_id)
    if material:
        keys = []
        for text in material:
            try:
                keys.append(asyncssh.import_public_key(text))
            except (asyncssh.KeyImportError, ValueError):
                continue
        if keys:
            return known_hosts_of(*keys)
    if LEGACY_KNOWN_HOSTS.is_file():
        return str(LEGACY_KNOWN_HOSTS)
    return known_hosts_of()


@app.post("/api/providers/connect")
async def connect_provider(request: DiscoveryRequest):
    host_key, fingerprint = await scan_ssh_host_key(request.vip, request.port)
    if not request.trusted_fingerprint:
        return {"status": "confirmation_required", "fingerprint": fingerprint, "message": "SSH 서버 호스트 키 지문을 확인해 주세요."}
    if request.trusted_fingerprint != fingerprint:
        raise HTTPException(409, "확인한 SSH 서버 호스트 키 지문이 현재 지문과 다릅니다.")
    private_key = None
    if request.auth_method == "private_key":
        try:
            private_key = asyncssh.import_private_key(request.private_key, request.passphrase)
        except (asyncssh.KeyImportError, asyncssh.KeyEncryptionError) as exc:
            raise HTTPException(400, "개인키 형식 또는 암호를 확인하세요.") from exc
    connect_options = {
        "port": request.port, "username": request.username, "known_hosts": trusted_known_hosts(host_key),
        "login_timeout": 10,
    }
    if request.auth_method == "private_key":
        connect_options.update(client_keys=[private_key], password=None)
    else:
        connect_options.update(client_keys=None, password=request.password, preferred_auth="password,keyboard-interactive")
    try:
        async with asyncssh.connect(request.vip, **connect_options) as connection:
            probe_command = (
                "PATH=\"$PATH:/usr/local/sbin:/usr/sbin:/sbin\"; "
                "printf 'hostname='; hostname; "
                "printf 'user='; id -un; "
                "if [ \"$(id -u)\" = 0 ]; then echo 'sudo=root'; "
                f"elif {SUDO_PROBE_COMMAND} >/dev/null 2>&1; then echo 'sudo=passwordless'; else echo 'sudo=authentication_required'; fi; "
                "for cmd in openstack systemctl docker podman pcs ceph ansible; do "
                "if command -v \"$cmd\" >/dev/null 2>&1; then echo \"tool=$cmd\"; fi; done"
            )
            result = await connection.run(probe_command, check=False, timeout=10)
            if result.exit_status != 0:
                raise HTTPException(502, "활성 Controller 정보를 확인할 수 없습니다.")
            probe = {}
            tools = []
            for line in result.stdout.splitlines():
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                if key == "tool":
                    tools.append(value)
                else:
                    probe[key] = value
            sudo_mode = probe.get("sudo", "unknown")
            sudo_password = None
            if sudo_mode == "authentication_required":
                # Non-root login without NOPASSWD: the checks need root, so verify a sudo password now
                # instead of registering an account that would later report every item as unavailable.
                candidate = request.sudo_password or (request.password if request.auth_method == "password" else None)
                if not candidate or "\n" in candidate or "\r" in candidate:
                    raise HTTPException(400, f"{probe.get('user', request.username)} 계정은 root가 아니며 비밀번호 없는 sudo가 허용되지 않습니다. 일일점검에 root 권한이 필요하므로 sudo 비밀번호를 입력하세요.")
                verification = await connection.run(SUDO_PASSWORD_CHECK_COMMAND, input=f"{candidate}\n", check=False, timeout=20)
                if verification.exit_status != 0:
                    source = "입력한 sudo 비밀번호" if request.sudo_password else "SSH 비밀번호"
                    raise HTTPException(400, f"{source}로 sudo 인증에 실패했습니다: {sudo_failure_reason(verification.stderr, verification.exit_status)}")
                sudo_mode = "password"
                sudo_password = candidate
            registered = {
                "status": "connected", "fingerprint": fingerprint,
                "controller_hostname": probe.get("hostname", "unknown"),
                "ssh_user": probe.get("user", request.username),
                "sudo_mode": sudo_mode,
                "available_tools": tools,
                "provider_id": save_provider({
                    "name": request.provider_name, "vip": request.vip, "port": request.port,
                    "username": request.username, "auth_method": request.auth_method,
                    "fingerprint": fingerprint, "controller_hostname": probe.get("hostname", "unknown"),
                    "sudo_mode": sudo_mode, "available_tools": tools,
                    # Keep the key itself, not just its fingerprint: node connections pin against
                    # stored key material, and the VIP is reachable before discovery has run.
                    "host_public_key": host_key.export_public_key().decode().strip(),
                }, {"private_key": request.private_key, "passphrase": request.passphrase, "password": request.password, "sudo_password": sudo_password}),
            }
            audit("provider.create", "provider", registered["provider_id"], request.provider_name,
                  f"VIP {request.vip}:{request.port} · 계정 {request.username} · {request.auth_method} · sudo {sudo_mode} · Controller {registered['controller_hostname']}")
            return registered
    except HTTPException:
        raise
    except (asyncssh.Error, OSError) as exc:
        raise HTTPException(502, f"SSH 연결에 실패했습니다: {type(exc).__name__}") from exc


@app.get("/api/providers")
async def providers_list():
    providers = list_providers()
    for provider in providers:
        check = latest_check(provider["id"])
        provider["latest_check"] = {key: check[key] for key in ("id", "status", "checked_at")} if check else None
        provider["database_credentials_configured"] = database_credentials_status(provider["id"])["configured"]
        provider["sudo_password_configured"] = sudo_password_configured(provider["id"])
        provider["profile"] = provider_setting(provider["id"], "profile")
        status_record = get_setting(f"provider:{provider['id']}:status") or {}
        provider["last_diagnosed_at"] = status_record.get("last_diagnosed_at")
        provider["last_diagnosis"] = status_record.get("last_diagnosis")
        provider["ssh_ok_at"] = status_record.get("ssh_ok_at")
        nodes = list_provider_nodes(provider["id"])
        provider["node_count"] = len(nodes)
        provider["maintenance_count"] = sum(1 for node in nodes if node.get("maintenance"))
    return {"providers": providers}


@app.get("/api/providers/{provider_id}/database-credentials")
async def get_provider_database_credentials(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return database_credentials_status(provider_id)


@app.put("/api/providers/{provider_id}/database-credentials")
async def update_provider_database_credentials(provider_id: str, request: DatabaseCredentialsRequest):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    save_database_credentials(provider_id, request.model_dump())
    audit("provider.db_credentials.set", "provider", provider_id, provider_label(provider_id), f"DB 계정 {request.username} @ {request.host}:{request.port}")
    return {"status": "saved", **database_credentials_status(provider_id)}


@app.delete("/api/providers/{provider_id}/database-credentials")
async def remove_provider_database_credentials(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    delete_database_credentials(provider_id)
    audit("provider.db_credentials.delete", "provider", provider_id, provider_label(provider_id))
    return {"status": "deleted", "configured": False}


@app.get("/api/providers/{provider_id}/sudo-credentials")
async def get_provider_sudo_credentials(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return sudo_status(provider)


@app.put("/api/providers/{provider_id}/sudo-credentials")
async def update_provider_sudo_credentials(provider_id: str, request: SudoCredentialsRequest):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if provider["username"] == "root":
        raise HTTPException(400, "root 계정으로 등록된 공급자는 sudo 비밀번호가 필요하지 않습니다.")
    host_key, fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
    if not is_provider_host_key_trusted(provider_id, fingerprint):
        flag_host_key_change(provider_id, fingerprint)
        raise HTTPException(409, detail={
            "code": "host_key_approval_required", "message": "새 SSH 호스트 키 승인이 필요합니다.",
            "fingerprint": fingerprint,
        })
    options = provider_ssh_options(provider)
    options["known_hosts"] = trusted_known_hosts(host_key)
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            mark_provider_host_key_seen(provider_id, fingerprint)
            result = await connection.run(SUDO_PASSWORD_CHECK_COMMAND, input=f"{request.sudo_password}\n", check=False, timeout=20)
    except (asyncssh.Error, OSError, TimeoutError) as exc:
        raise HTTPException(502, f"sudo 비밀번호 확인을 위한 SSH 연결에 실패했습니다: {type(exc).__name__}") from exc
    if result.exit_status != 0:
        raise HTTPException(400, f"sudo 비밀번호 확인에 실패했습니다: {sudo_failure_reason(result.stderr, result.exit_status)}")
    update_provider_sudo(provider_id, request.sudo_password, "password")
    audit("provider.sudo_credentials.set", "provider", provider_id, provider["name"], f"계정 {provider['username']} · Controller에서 검증됨")
    return {"status": "saved", **sudo_status(get_provider(provider_id))}


@app.delete("/api/providers/{provider_id}/sudo-credentials")
async def remove_provider_sudo_credentials(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    update_provider_sudo(provider_id, None, "root" if provider["username"] == "root" else "authentication_required")
    audit("provider.sudo_credentials.delete", "provider", provider_id, provider["name"], f"계정 {provider['username']}")
    return {"status": "deleted", **sudo_status(get_provider(provider_id))}


@app.get("/api/providers/{provider_id}/host-keys")
async def provider_host_keys(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"provider_id": provider_id, "keys": list_provider_host_keys(provider_id), "events": list_host_key_events(provider_id)}


@app.post("/api/providers/{provider_id}/host-keys/probe")
async def probe_provider_host_key(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    _, fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
    trusted = is_provider_host_key_trusted(provider_id, fingerprint)
    if trusted:
        mark_provider_host_key_seen(provider_id, fingerprint)
    return {
        "provider_id": provider_id, "provider_name": provider["name"], "address": provider["vip"],
        "fingerprint": fingerprint, "trusted": trusted,
    }


@app.post("/api/providers/{provider_id}/host-keys/approve")
async def approve_provider_host_key(provider_id: str, request: HostKeyApprovalRequest):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    host_key, current_fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
    if request.fingerprint != current_fingerprint:
        raise HTTPException(409, "승인 요청 지문과 현재 SSH 서버 지문이 다릅니다. 다시 조회해 주세요.")
    options = provider_ssh_options(provider)
    options["known_hosts"] = trusted_known_hosts(host_key)
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            result = await connection.run("hostname -s", check=True, timeout=10)
            hostname = result.stdout.strip()
    except (asyncssh.Error, OSError, TimeoutError) as exc:
        raise HTTPException(502, f"승인할 Controller의 신원을 확인하지 못했습니다: {type(exc).__name__}") from exc
    trusted_key = trust_provider_host_key(provider_id, current_fingerprint, hostname, provider["vip"])
    from provider_store import resolve_monitoring_alert
    resolve_monitoring_alert(provider_id, "security:host_key", f"운영자가 지문 {current_fingerprint}을 승인했습니다.", category="security")
    audit("provider.host_key.approve", "provider", provider_id, provider["name"], f"{hostname} {current_fingerprint}")
    return {"status": "approved", "key": trusted_key}


@app.delete("/api/providers/{provider_id}/host-keys/{key_id}")
async def remove_provider_host_key(provider_id: str, key_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    try:
        deleted = delete_provider_host_key(provider_id, key_id)
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    if not deleted:
        raise HTTPException(404, "등록된 SSH 지문을 찾을 수 없습니다.")
    audit("provider.host_key.revoke", "provider", provider_id, provider_label(provider_id), f"지문 ID {key_id}")
    return {"status": "deleted"}


@app.get("/api/providers/{provider_id}/latest-check")
async def provider_latest_check(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"latest_check": latest_check(provider_id)}


def provider_ssh_options(provider: dict) -> dict:
    credentials = provider["credentials"]
    options = {"port": provider["port"], "username": provider["username"], "known_hosts": None, "login_timeout": 10}
    if provider["auth_method"] == "private_key":
        try:
            key = asyncssh.import_private_key(credentials["private_key"], credentials.get("passphrase"))
        except (asyncssh.KeyImportError, asyncssh.KeyEncryptionError) as exc:
            raise HTTPException(500, "저장된 SSH 개인키를 사용할 수 없습니다.") from exc
        options.update(client_keys=[key], password=None)
    else:
        options.update(client_keys=None, password=credentials.get("password"), preferred_auth="password,keyboard-interactive")
    return options


class PrivilegeError(RuntimeError):
    """The login account could not obtain root on the target node."""


class AddressResolutionError(OSError):
    """A node has no usable IP and its hostname cannot be resolved locally."""


def is_ip_address(value: str) -> bool:
    try:
        ipaddress.ip_address(value)
        return True
    except ValueError:
        return False


async def resolve_node_address(node: dict) -> str:
    """Prefer the IP stored in the inventory; only fall back to local name resolution.

    Node names discovered through pcs/openstack usually exist only in the cluster's
    own /etc/hosts, so resolving them on the deploy server fails (gaierror) unless
    an operator mirrored the entries. Discovery now resolves each name on the
    controller and stores the IP, making the stored address authoritative.
    """
    address = (node.get("address") or "").strip()
    if address and is_ip_address(address):
        return address
    for candidate in (address, (node.get("hostname") or "").strip()):
        if not candidate or is_ip_address(candidate):
            continue
        try:
            return await asyncio.to_thread(socket.gethostbyname, candidate)
        except OSError:
            continue
    raise AddressResolutionError(
        f"호스트명 '{node.get('hostname') or address}'의 IP를 확인할 수 없습니다. "
        "클러스터 탐색을 다시 실행해 노드 IP를 갱신하거나 배포 서버의 DNS 또는 /etc/hosts 등록을 확인하세요."
    )


def node_failure_reason(exc: Exception) -> str:
    if isinstance(exc, AddressResolutionError):
        return str(exc)
    if isinstance(exc, PrivilegeError):
        return f"root 권한 획득 실패 — {exc}"
    if isinstance(exc, asyncssh.HostKeyNotVerifiable):
        return ("SSH 호스트 키 미등록 — 클러스터 탐색을 다시 실행하면 활성 Controller에서 노드 호스트 키를 "
                "수집해 등록합니다. 노드를 수동으로 추가했거나 노드 SSH 키가 교체된 경우에도 탐색을 다시 실행하세요.")
    if isinstance(exc, socket.gaierror):
        return "접속 주소를 IP로 해석하지 못했습니다"
    return type(exc).__name__


def sudo_failure_reason(stderr: str, exit_status: int | None) -> str:
    lines = [line.strip() for line in (stderr or "").splitlines() if line.strip()]
    message = lines[-1] if lines else f"exit {exit_status}"
    if "incorrect password" in message or "Sorry, try again" in message:
        return "sudo 비밀번호가 일치하지 않습니다"
    if "not in the sudoers" in message or "not allowed" in message:
        return f"sudo 권한이 없습니다 ({message})"
    if "tty" in message:
        return f"sudoers의 requiretty 설정으로 비대화형 sudo가 차단되었습니다 ({message})"
    if "password is required" in message:
        return "sudo 비밀번호가 필요합니다"
    return f"sudo 실행 실패 ({message})"


async def run_as_root(connection, provider: dict, script: str, timeout: int):
    """Run a check script as root on an established SSH connection.

    A root login runs the script unchanged. Any other account is escalated with sudo:
    NOPASSWD when the node allows it, otherwise the stored sudo password is written to
    sudo's stdin (`-S`) ahead of the script, which `bash -s` then reads. `-k` forces a
    fresh authentication so the password line is always consumed by sudo, and `-H`
    makes `$HOME` resolve to /root for OpenRC discovery. The script is never silently
    executed without privileges: an unprivileged run cannot read service logs and would
    misreport them as healthy, so a failed escalation raises PrivilegeError instead.
    """
    if provider["username"] == "root":
        return await connection.run("bash -s", input=script, check=False, timeout=timeout)
    payload = f"printf '%s\\n' {ROOT_MARKER}\n{script}"
    probe = await connection.run(SUDO_PROBE_COMMAND, check=False, timeout=20)
    if probe.exit_status == 0:
        result = await connection.run(SUDO_NOPASSWD_COMMAND, input=payload, check=False, timeout=timeout)
    else:
        sudo_password = provider["credentials"].get("sudo_password")
        if not sudo_password:
            raise PrivilegeError(f"{provider['username']} 계정: {sudo_failure_reason(probe.stderr, probe.exit_status)} (공급자 화면에서 sudo 비밀번호를 등록하세요)")
        result = await connection.run(SUDO_PASSWORD_COMMAND, input=f"{sudo_password}\n{payload}", check=False, timeout=timeout)
    if not result.stdout.startswith(ROOT_MARKER + "\n"):
        raise PrivilegeError(f"{provider['username']} 계정: {sudo_failure_reason(result.stderr, result.exit_status)}")
    return SimpleNamespace(stdout=result.stdout[len(ROOT_MARKER) + 1:], stderr=result.stderr, exit_status=result.exit_status)


@app.get("/api/providers/{provider_id}/nodes")
async def provider_nodes(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    return {"provider_id": provider_id, "nodes": nodes, "count": len(nodes), "maintenance_count": sum(1 for node in nodes if node.get("maintenance"))}


# --- Provider management: edit, connection diagnosis, node inventory editing -----------------------
NODE_ROLES = {"controller", "compute", "storage", "network"}
HOSTNAME_PATTERN = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,252})$")


class ProviderNodeRequest(BaseModel):
    hostname: str = Field(min_length=1, max_length=253)
    role: str = "compute"
    address: str = Field(default="", max_length=253)
    note: str = Field(default="", max_length=300)


class ProviderNodePatch(BaseModel):
    role: str | None = None
    address: str | None = Field(default=None, max_length=253)
    maintenance: bool | None = None
    note: str | None = Field(default=None, max_length=300)


class ProviderUpdateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    vip: str = Field(min_length=1, max_length=253)
    port: int = Field(default=22, ge=1, le=65535)
    username: str = Field(min_length=1, max_length=64)
    auth_method: str | None = None
    private_key: str | None = None
    passphrase: str | None = None
    password: str | None = None
    sudo_password: str | None = Field(default=None, max_length=1024, pattern=r"^[^\r\n\x00]+$")
    trusted_fingerprint: str | None = None


def provider_public(provider: dict) -> dict:
    return {key: provider[key] for key in ("id", "name", "vip", "port", "username", "auth_method", "controller_hostname", "sudo_mode", "available_tools", "created_at") if key in provider} | {"updated_at": provider.get("updated_at")}


@app.post("/api/providers/{provider_id}/nodes", status_code=201)
async def add_provider_node(provider_id: str, payload: ProviderNodeRequest):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    hostname = payload.hostname.strip()
    if not HOSTNAME_PATTERN.match(hostname):
        raise HTTPException(400, "호스트명 형식이 올바르지 않습니다.")
    if payload.role not in NODE_ROLES:
        raise HTTPException(400, "역할은 controller, compute, storage, network 중 하나여야 합니다.")
    address = payload.address.strip() or hostname
    node = upsert_provider_node(provider_id, hostname, payload.role, address, payload.note.strip())
    audit("provider.node.add", "provider", provider_id, provider["name"], f"{hostname} · {payload.role} · {address}")
    return node


@app.patch("/api/providers/{provider_id}/nodes/{hostname}")
async def edit_provider_node(provider_id: str, hostname: str, payload: ProviderNodePatch):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    changes = {}
    if payload.role is not None:
        if payload.role not in NODE_ROLES:
            raise HTTPException(400, "역할은 controller, compute, storage, network 중 하나여야 합니다.")
        changes["role"] = payload.role
    if payload.address is not None:
        changes["address"] = payload.address.strip() or hostname
    if payload.maintenance is not None:
        changes["maintenance"] = payload.maintenance
    if payload.note is not None:
        changes["note"] = payload.note.strip()
    node = update_provider_node(provider_id, hostname, changes)
    if not node:
        raise HTTPException(404, "등록된 노드를 찾을 수 없습니다.")
    detail = " · ".join(f"{key}={value}" for key, value in changes.items())
    audit("provider.node.update", "provider", provider_id, provider["name"], f"{hostname} · {detail}")
    return node


@app.delete("/api/providers/{provider_id}/nodes/{hostname}")
async def remove_provider_node(provider_id: str, hostname: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if not delete_provider_node(provider_id, hostname):
        raise HTTPException(404, "등록된 노드를 찾을 수 없습니다.")
    audit("provider.node.delete", "provider", provider_id, provider["name"], hostname)
    return {"status": "deleted", "hostname": hostname}


@app.put("/api/providers/{provider_id}")
async def edit_provider(provider_id: str, request: ProviderUpdateRequest):
    """Edit a provider in place. A pure rename is saved directly; any connection change is verified over SSH first,
    with the same host-key confirmation step as registration when the Controller's fingerprint is not yet trusted."""
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if CHECK_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "점검이 실행 중입니다. 완료 후 수정하세요.")
    auth_method = request.auth_method or provider["auth_method"]
    if auth_method not in {"private_key", "password"}:
        raise HTTPException(400, "인증 방식은 private_key 또는 password여야 합니다.")
    credentials = dict(provider["credentials"])
    new_secret = bool(request.private_key or request.password or request.sudo_password or request.passphrase)
    connection_changed = (request.vip.strip() != provider["vip"] or request.port != provider["port"] or request.username.strip() != provider["username"]
                          or auth_method != provider["auth_method"] or new_secret)
    name = request.name.strip()
    if not connection_changed:
        updated = update_provider(provider_id, {"name": name})
        audit("provider.update", "provider", provider_id, name, f"이름 변경 {provider['name']} → {name}" if name != provider["name"] else "변경 없음")
        return {"status": "updated", "provider": provider_public(updated)}
    if auth_method == "private_key":
        if request.private_key:
            credentials["private_key"] = request.private_key
            credentials["passphrase"] = request.passphrase
        elif not credentials.get("private_key"):
            raise HTTPException(400, "개인키 인증으로 바꾸려면 SSH 개인키를 올려야 합니다.")
        try:
            asyncssh.import_private_key(credentials["private_key"], credentials.get("passphrase"))
        except (asyncssh.KeyImportError, asyncssh.KeyEncryptionError) as exc:
            raise HTTPException(400, "개인키 형식 또는 암호를 확인하세요.") from exc
    else:
        if request.password:
            credentials["password"] = request.password
        elif not credentials.get("password"):
            raise HTTPException(400, "비밀번호 인증으로 바꾸려면 SSH 비밀번호를 입력해야 합니다.")
    if request.sudo_password:
        credentials["sudo_password"] = request.sudo_password
    vip, port, username = request.vip.strip(), request.port, request.username.strip()
    host_key, fingerprint = await scan_ssh_host_key(vip, port)
    trusted = is_provider_host_key_trusted(provider_id, fingerprint) or request.trusted_fingerprint == fingerprint
    if not trusted:
        return {"status": "confirmation_required", "fingerprint": fingerprint, "message": "변경한 주소의 SSH 호스트 키 지문을 확인해 주세요."}
    candidate = {**provider, "vip": vip, "port": port, "username": username, "auth_method": auth_method, "credentials": credentials}
    options = provider_ssh_options(candidate)
    options["known_hosts"] = trusted_known_hosts(host_key)
    probe_command = (
        "PATH=\"$PATH:/usr/local/sbin:/usr/sbin:/sbin\"; printf 'hostname='; hostname; printf 'user='; id -un; "
        "if [ \"$(id -u)\" = 0 ]; then echo 'sudo=root'; "
        f"elif {SUDO_PROBE_COMMAND} >/dev/null 2>&1; then echo 'sudo=passwordless'; else echo 'sudo=authentication_required'; fi; "
        "for cmd in openstack systemctl docker podman pcs ceph ansible; do if command -v \"$cmd\" >/dev/null 2>&1; then echo \"tool=$cmd\"; fi; done"
    )
    try:
        async with asyncssh.connect(vip, **options) as connection:
            result = await connection.run(probe_command, check=False, timeout=10)
            if result.exit_status != 0:
                raise HTTPException(502, "활성 Controller 정보를 확인할 수 없습니다.")
            probe, tools = {}, []
            for line in result.stdout.splitlines():
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                (tools.append(value) if key == "tool" else probe.__setitem__(key, value))
            sudo_mode = probe.get("sudo", "unknown")
            if sudo_mode == "authentication_required":
                secret = credentials.get("sudo_password") or (credentials.get("password") if auth_method == "password" else None)
                if not secret:
                    raise HTTPException(400, f"{probe.get('user', username)} 계정은 root가 아니며 비밀번호 없는 sudo가 허용되지 않습니다. sudo 비밀번호를 입력하세요.")
                verification = await connection.run(SUDO_PASSWORD_CHECK_COMMAND, input=f"{secret}\n", check=False, timeout=20)
                if verification.exit_status != 0:
                    raise HTTPException(400, f"sudo 인증에 실패했습니다: {sudo_failure_reason(verification.stderr, verification.exit_status)}")
                sudo_mode = "password"
                credentials["sudo_password"] = secret
            else:
                credentials["sudo_password"] = credentials.get("sudo_password") if sudo_mode != "root" else None
    except HTTPException:
        raise
    except (asyncssh.Error, OSError, TimeoutError) as exc:
        raise HTTPException(502, f"SSH 연결에 실패했습니다: {type(exc).__name__}") from exc
    updated = update_provider(provider_id, {
        "name": name, "vip": vip, "port": port, "username": username, "auth_method": auth_method,
        "fingerprint": fingerprint, "controller_hostname": probe.get("hostname", provider["controller_hostname"]), "sudo_mode": sudo_mode, "available_tools": tools,
    }, credentials)
    if not is_provider_host_key_trusted(provider_id, fingerprint):
        trust_provider_host_key(provider_id, fingerprint, probe.get("hostname", ""), vip)
    else:
        mark_provider_host_key_seen(provider_id, fingerprint)
    audit("provider.update", "provider", provider_id, name,
          f"VIP {vip}:{port} · 계정 {username} · {auth_method} · sudo {sudo_mode} · Controller {probe.get('hostname', '-')}" + (" · 인증정보 교체" if new_secret else ""))
    return {"status": "updated", "provider": provider_public(updated), "sudo_mode": sudo_mode, "controller_hostname": probe.get("hostname"), "available_tools": tools}


async def tcp_reachable(host: str, port: int, timeout: float = 5) -> tuple[bool, str]:
    try:
        _, writer = await asyncio.wait_for(asyncio.open_connection(host, port), timeout=timeout)
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:  # noqa: BLE001
            pass
        return True, ""
    except asyncio.TimeoutError:
        return False, f"{timeout:.0f}초 안에 응답 없음"
    except (OSError, socket.gaierror) as exc:
        return False, type(exc).__name__ if not str(exc) else str(exc)[:120]


def host_key_registered(provider_id: str, *names: str) -> bool:
    """Whether a node's host key is trusted for this provider.

    Prefers the keys collected during discovery. The deploy server's `known_hosts` is consulted
    only for providers discovered before keys were stored, and it does not exist in a container.
    """
    wanted = {name for name in names if name}
    if any(entry["hostname"] in wanted and entry["public_key"] for entry in list_provider_host_keys(provider_id)):
        return True
    try:
        text = LEGACY_KNOWN_HOSTS.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    return any(re.search(rf"(^|[ ,\[]){re.escape(name)}([ ,\]:]|$)", text, re.MULTILINE) for name in wanted)


@app.post("/api/providers/{provider_id}/diagnose")
async def diagnose_provider(provider_id: str):
    """Connection readiness: VIP reachability, host key trust, SSH login, root escalation, OpenRC/CLI, node reachability, Prometheus, DB credentials."""
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    steps: list[dict] = []
    started_all = datetime.now(timezone.utc)

    def add(key: str, label: str, status: str, detail: str, started: datetime) -> None:
        steps.append({"key": key, "label": label, "status": status, "detail": detail[:500], "seconds": round((datetime.now(timezone.utc) - started).total_seconds(), 2)})

    t = datetime.now(timezone.utc)
    reachable, reason = await tcp_reachable(provider["vip"], provider["port"])
    add("tcp", f"VIP {provider['vip']}:{provider['port']} 접속", "ok" if reachable else "fail", "TCP 연결 성공" if reachable else f"TCP 연결 실패: {reason}", t)
    host_key = None
    fingerprint = None
    if reachable:
        t = datetime.now(timezone.utc)
        try:
            host_key, fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
            trusted = is_provider_host_key_trusted(provider_id, fingerprint)
            add("host_key", "SSH 호스트 키", "ok" if trusted else "fail", f"{fingerprint} · {'신뢰 목록에 있음' if trusted else '승인되지 않은 지문 · SSH 키 관리에서 승인 필요'}", t)
            if not trusted:
                host_key = None
        except HTTPException as exc:
            add("host_key", "SSH 호스트 키", "fail", str(exc.detail), t)
    else:
        add("host_key", "SSH 호스트 키", "skip", "VIP에 연결할 수 없어 건너뜀", t)
    ssh_ok = False
    if host_key is not None:
        t = datetime.now(timezone.utc)
        try:
            options = provider_ssh_options(provider)
            options["known_hosts"] = trusted_known_hosts(host_key)
            async with asyncssh.connect(provider["vip"], **options) as connection:
                mark_provider_host_key_seen(provider_id, fingerprint)
                result = await connection.run("hostname; id -un", check=False, timeout=10)
                lines = result.stdout.split()
                ssh_ok = result.exit_status == 0
                add("ssh", f"SSH 로그인 ({provider['username']})", "ok" if ssh_ok else "fail", f"활성 Controller {lines[0] if lines else '-'}" + (f" · 등록된 Controller {provider['controller_hostname']}와 다름" if lines and lines[0] != provider["controller_hostname"] else ""), t)
                if ssh_ok:
                    t = datetime.now(timezone.utc)
                    try:
                        root = await run_as_root(connection, provider, "id -u </dev/null", 20)
                        root_ok = root.exit_status == 0 and root.stdout.strip().endswith("0")
                        add("sudo", "root 권한 획득", "ok" if root_ok else "fail", "root 계정" if provider["username"] == "root" else (f"sudo 성공 ({provider.get('sudo_mode')})" if root_ok else f"sudo 실패: {(root.stderr or '').strip()[:200] or 'root 권한을 얻지 못함'}"), t)
                    except Exception as exc:  # noqa: BLE001
                        root_ok = False
                        add("sudo", "root 권한 획득", "fail", f"{type(exc).__name__}: {str(exc)[:200]}", t)
                    t = datetime.now(timezone.utc)
                    if root_ok:
                        openrc_script = (
                            "openrc=''; for candidate in /root/contrabass-openrc \"$HOME/contrabass-openrc\" /root/admin-openrc.sh /etc/kolla/admin-openrc.sh; do [ -r \"$candidate\" ] && openrc=\"$candidate\" && break; done; "
                            "if [ -z \"$openrc\" ]; then echo 'openrc=missing'; exit 0; fi; echo \"openrc=$openrc\"; . \"$openrc\" >/dev/null 2>&1; "
                            "if ! command -v openstack >/dev/null 2>&1; then echo 'cli=missing'; exit 0; fi; "
                            "if out=$(timeout -k 5 30 openstack token issue -f value -c expires </dev/null 2>&1); then echo \"token=$out\"; else echo \"error=$(echo \"$out\" | tail -1 | cut -c1-200)\"; fi"
                        )
                        try:
                            probe = await run_as_root(connection, provider, openrc_script, 60)
                            values = dict(line.split("=", 1) for line in probe.stdout.splitlines() if "=" in line)
                            if values.get("openrc") == "missing":
                                add("openrc", "OpenRC · OpenStack CLI", "fail", "/root/contrabass-openrc 등 OpenRC 파일을 찾지 못함", t)
                            elif values.get("cli") == "missing":
                                add("openrc", "OpenRC · OpenStack CLI", "fail", f"{values.get('openrc')} 있음 · openstack CLI 없음", t)
                            elif values.get("token"):
                                add("openrc", "OpenRC · OpenStack CLI", "ok", f"{values.get('openrc')} · Keystone 토큰 발급 성공 (만료 {values['token'][:25]})", t)
                            else:
                                add("openrc", "OpenRC · OpenStack CLI", "fail", f"{values.get('openrc')} · 토큰 발급 실패: {values.get('error', '-')}", t)
                        except Exception as exc:  # noqa: BLE001
                            add("openrc", "OpenRC · OpenStack CLI", "fail", f"{type(exc).__name__}: {str(exc)[:200]}", t)
                    else:
                        add("openrc", "OpenRC · OpenStack CLI", "skip", "root 권한이 없어 건너뜀", t)
        except (asyncssh.Error, OSError, TimeoutError) as exc:
            add("ssh", f"SSH 로그인 ({provider['username']})", "fail", f"{type(exc).__name__}: {str(exc)[:200]}", t)
    else:
        add("ssh", f"SSH 로그인 ({provider['username']})", "skip", "호스트 키가 신뢰되지 않아 건너뜀", t)
    nodes = list_provider_nodes(provider_id)
    t = datetime.now(timezone.utc)
    if not nodes:
        add("nodes", "클러스터 노드", "fail", "탐색된 노드가 없음 · 클러스터 노드 탐색을 실행하세요", t)
    else:
        async def probe_node(node: dict) -> dict:
            try:
                address = await resolve_node_address(node)
            except Exception as exc:  # noqa: BLE001
                return {"hostname": node["hostname"], "status": "fail", "detail": f"주소 해석 실패: {type(exc).__name__}"}
            ok, reason = await tcp_reachable(address, 22)
            known = host_key_registered(provider_id, node["hostname"], node["hostname"].split(".")[0], address)
            if not ok:
                return {"hostname": node["hostname"], "status": "fail", "detail": f"{address}:22 연결 실패: {reason}"}
            return {"hostname": node["hostname"], "status": "ok" if known else "warn", "detail": f"{address}:22 연결 가능" + ("" if known else " · 호스트 키 미등록 (클러스터 탐색을 다시 실행하세요)")}
        results = await asyncio.gather(*(probe_node(node) for node in nodes))
        failed = [item for item in results if item["status"] == "fail"]
        warned = [item for item in results if item["status"] == "warn"]
        maintenance = sum(1 for node in nodes if node.get("maintenance"))
        status = "fail" if failed else ("warn" if warned else "ok")
        detail = f"{len(nodes)}대 중 접속 가능 {len(nodes) - len(failed)}대" + (f" · 호스트 키 미등록 {len(warned)}대" if warned else "") + (f" · 정비 중 {maintenance}대" if maintenance else "")
        steps.append({"key": "nodes", "label": "클러스터 노드 SSH 포트", "status": status, "detail": detail, "seconds": round((datetime.now(timezone.utc) - t).total_seconds(), 2), "nodes": results})
    t = datetime.now(timezone.utc)
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            prometheus = await discover_prometheus(client, provider, nodes)
        add("prometheus", "Prometheus 수집원", "ok" if prometheus else "warn", f"{prometheus} 연결됨" if prometheus else "Prometheus를 찾지 못함 · 모니터링은 점검 이력으로 대체", t)
    except Exception as exc:  # noqa: BLE001
        add("prometheus", "Prometheus 수집원", "warn", f"확인 실패: {type(exc).__name__}", t)
    t = datetime.now(timezone.utc)
    add("database", "MySQL 점검 인증", "ok" if provider.get("database_credentials") else "warn", "DB 인증정보 등록됨" if provider.get("database_credentials") else "미등록 · Middleware MySQL 항목은 확인 불가로 표시됨", t)
    schedule = get_check_schedule(provider_id)
    add("schedule", "예약 실행", "ok" if schedule.get("enabled") else "warn", f"매일 {schedule.get('run_time')}" if schedule.get("enabled") else "예약 없음", t)
    summary = {"ok": sum(1 for step in steps if step["status"] == "ok"), "warn": sum(1 for step in steps if step["status"] == "warn"), "fail": sum(1 for step in steps if step["status"] == "fail"), "skip": sum(1 for step in steps if step["status"] == "skip")}
    diagnosed_at = datetime.now(timezone.utc).isoformat()
    status_record = get_setting(f"provider:{provider_id}:status") or {}
    status_record.update({"last_diagnosed_at": diagnosed_at, "last_diagnosis": summary, "ssh_ok_at": diagnosed_at if ssh_ok else status_record.get("ssh_ok_at")})
    set_setting(f"provider:{provider_id}:status", status_record, "diagnose")
    audit("provider.diagnose", "provider", provider_id, provider["name"], f"정상 {summary['ok']} · 주의 {summary['warn']} · 실패 {summary['fail']}")
    return {"provider_id": provider_id, "diagnosed_at": diagnosed_at, "duration_seconds": round((datetime.now(timezone.utc) - started_all).total_seconds(), 1), "summary": summary, "steps": steps,
            "overall": "fail" if summary["fail"] else ("warn" if summary["warn"] else "ok")}


@app.get("/api/providers/{provider_id}/status")
async def provider_status(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    record = get_setting(f"provider:{provider_id}:status") or {}
    checks = list_checks(provider_id, 1)
    return {"provider_id": provider_id, **record, "last_check_at": checks[0]["checked_at"] if checks else None, "last_check_status": checks[0]["status"] if checks else None,
            "profile": provider_setting(provider_id, "profile"), "updated_at": provider.get("updated_at")}


def store_discovered_host_keys(provider_id: str, collected: list[tuple[str, str, str]], discovered: dict) -> int:
    """Trust the node host keys the active controller reported, so node connections can be pinned.

    The controller is already an authenticated peer - we reached it with a key the operator
    approved by fingerprint - so keys arriving over that channel are a better trust anchor than
    scanning each node from here and accepting whatever answers.
    """
    stored = 0
    for hostname, address, key_text in collected:
        try:
            key = asyncssh.import_public_key(key_text)
        except (asyncssh.KeyImportError, ValueError):
            continue
        node = discovered.get(hostname) or discovered.get(hostname.split(".")[0]) or {}
        trust_provider_host_key(provider_id, key.get_fingerprint("sha256"), hostname, address,
                                public_key=key_text, role=node.get("role", ""))
        stored += 1
    return stored


@app.post("/api/providers/{provider_id}/discover")
async def discover_provider_nodes(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    host_key, fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
    if not is_provider_host_key_trusted(provider_id, fingerprint):
        flag_host_key_change(provider_id, fingerprint)
        raise HTTPException(409, detail={
            "code": "host_key_approval_required", "message": "새 SSH 호스트 키 승인이 필요합니다.",
            "fingerprint": fingerprint,
        })
    options = provider_ssh_options(provider)
    options["known_hosts"] = trusted_known_hosts(host_key)
    command = r'''
node_names="$(hostname -s)"
printf 'controller=%s|active-vip\n' "$(hostname -s)"
if command -v pcs >/dev/null 2>&1; then
  pcs_nodes=$(pcs status nodes 2>/dev/null | awk '/Online:/{line=$0; sub(/^.*Online:[[:space:]]*\[/,"",line); sub(/\].*$/,"",line); count=split(line,nodes,/ +/); for(i=1;i<=count;i++) if(nodes[i]!="") print nodes[i]}')
  for name in $pcs_nodes; do printf 'controller=%s|pcs\n' "$name"; node_names="$node_names $name"; done
fi
openrc_source=""
for candidate in "$HOME/contrabass-openrc" "$HOME/admin-openrc.sh" "$HOME/openrc" /etc/kolla/admin-openrc.sh /root/contrabass-openrc /root/admin-openrc.sh /root/keystonerc_admin; do
  if [ -r "$candidate" ]; then . "$candidate" >/dev/null 2>&1 && openrc_source="$candidate" && break; fi
done
if command -v openstack >/dev/null 2>&1; then
  compute_hosts=$(openstack compute service list --service nova-compute -f value -c Host 2>/dev/null | awk 'NF{print $1}')
  for name in $compute_hosts; do printf 'compute=%s|openstack\n' "$name"; node_names="$node_names $name"; done
  [ -n "$openrc_source" ] && printf 'meta=openrc|%s\n' "$openrc_source"
else
  printf 'warning=openstack CLI를 찾을 수 없습니다.\n'
fi
seen_addrs=""
for name in $node_names; do
  addr=$(getent ahostsv4 "$name" 2>/dev/null | awk 'NR==1{print $1}')
  [ -z "$addr" ] && addr=$(getent hosts "$name" 2>/dev/null | awk 'NR==1{print $1}')
  case "$addr" in 127.*|::1|"") continue;; esac
  printf 'addr=%s|%s\n' "$name" "$addr"
  # 노드 호스트 키를 Controller 에서 모아 둔다. 이 플랫폼이 컨테이너로 돌 때는 배포 서버의
  # known_hosts 를 쓸 수 없고, 새로 만든 배포 서버에서도 그 파일은 비어 있기 때문이다.
  case " $seen_addrs " in *" $addr "*) continue;; esac
  seen_addrs="$seen_addrs $addr"
  if command -v ssh-keyscan >/dev/null 2>&1; then
    ssh-keyscan -T 5 -t rsa,ecdsa,ed25519 "$addr" 2>/dev/null \
      | awk -v n="$name" -v a="$addr" '$2!="" && $3!="" {printf "hostkey=%s|%s|%s %s\n", n, a, $2, $3}'
  fi
done
command -v ssh-keyscan >/dev/null 2>&1 || printf 'warning=Controller에 ssh-keyscan이 없어 노드 호스트 키를 수집하지 못했습니다.\n'
exit 0
'''
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            mark_provider_host_key_seen(provider_id, fingerprint)
            response = await run_as_root(connection, provider, command, 30)
    except HTTPException:
        raise
    except PrivilegeError as exc:
        raise HTTPException(502, f"클러스터 탐색에 필요한 root 권한을 얻지 못했습니다: {exc}") from exc
    except (asyncssh.Error, OSError, TimeoutError) as exc:
        raise HTTPException(502, f"클러스터 탐색 연결에 실패했습니다: {type(exc).__name__}") from exc
    if response.exit_status != 0:
        raise HTTPException(502, "클러스터 노드 탐색 명령 실행에 실패했습니다.")
    discovered = {}
    warnings = []
    sources = set()
    addresses = {}
    node_host_keys: list[tuple[str, str, str]] = []
    for line in response.stdout.splitlines():
        if line.startswith("warning="):
            warnings.append(line.split("=", 1)[1])
            continue
        if line.startswith("meta=openrc|"):
            sources.add(f"OpenRC: {line.split('|', 1)[1]}")
            continue
        if line.startswith("hostkey="):
            key_match = re.fullmatch(r"hostkey=([a-zA-Z0-9][a-zA-Z0-9._-]{0,252})\|([0-9a-fA-F:.]+)\|(\S+ \S+)", line)
            if key_match:
                name, address, key_text = key_match.groups()
                node_host_keys.append((name, address, key_text))
            continue
        address_match = re.fullmatch(r"addr=([a-zA-Z0-9][a-zA-Z0-9._-]{0,252})\|([0-9a-fA-F:.]+)", line)
        if address_match:
            name, address = address_match.groups()
            if is_ip_address(address):
                addresses[name] = address
                addresses.setdefault(name.split(".")[0], address)
            continue
        match = re.fullmatch(r"(controller|compute)=([a-zA-Z0-9][a-zA-Z0-9._-]{0,252})\|([a-zA-Z0-9_-]+)", line)
        if not match:
            continue
        role, hostname, source = match.groups()
        current = discovered.get(hostname)
        if current and current["role"] == "controller":
            continue
        discovered[hostname] = {"hostname": hostname, "address": hostname, "role": role, "source": source}
        sources.add(source)
    active_hostname = provider["controller_hostname"].split(".")[0]
    if not discovered:
        discovered[active_hostname] = {"hostname": active_hostname, "address": provider["vip"], "role": "controller", "source": "active-vip"}
    unresolved = []
    for node in discovered.values():
        # The controller resolved each name through the cluster's own hosts/DNS,
        # so a stored IP works even when the deploy server cannot resolve the name.
        address = addresses.get(node["hostname"]) or addresses.get(node["hostname"].split(".")[0])
        if address:
            node["address"] = address
        elif node["hostname"].split(".")[0] == active_hostname:
            node["address"] = provider["vip"]
        elif not is_ip_address(node["address"]):
            unresolved.append(node["hostname"])
    if unresolved:
        warnings.append(
            "Controller에서 다음 노드의 IP를 해석하지 못했습니다: " + ", ".join(sorted(unresolved))
            + ". 배포 서버의 DNS 또는 /etc/hosts 등록이 없으면 해당 노드 점검이 실패합니다."
        )
    nodes = list(discovered.values())
    save_provider_nodes(provider_id, nodes)
    stored_keys = store_discovered_host_keys(provider_id, node_host_keys, discovered)
    audit("provider.discover", "provider", provider_id, provider["name"], f"노드 {len(nodes)}대 · " + ", ".join(sorted(node["hostname"] for node in nodes)[:12]))
    if not any(node["role"] == "compute" for node in nodes):
        warnings.append("Compute 노드를 찾지 못했습니다. Controller의 OpenStack 인증 환경을 확인하세요.")
    if stored_keys:
        audit("provider.host_keys", "provider", provider_id, provider["name"], f"노드 호스트 키 {stored_keys}개 등록")
    else:
        warnings.append(
            "노드 호스트 키를 수집하지 못했습니다. 이 플랫폼을 컨테이너로 운영한다면 노드 점검이 "
            "호스트 키 미등록으로 실패합니다. Controller에 ssh-keyscan이 있는지 확인하세요."
        )
    return {"provider_id": provider_id, "nodes": nodes, "count": len(nodes), "sources": sorted(sources),
            "warnings": warnings, "host_keys": stored_keys}


@app.delete("/api/providers/{provider_id}")
async def remove_provider(provider_id: str):
    existing = get_provider(provider_id)
    if not delete_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    audit("provider.delete", "provider", provider_id, existing["name"] if existing else provider_id, f"VIP {existing['vip']}" if existing else "")
    return {"status": "deleted", "provider_id": provider_id}


@app.get("/api/providers/{provider_id}/check-exceptions")
async def get_check_exceptions(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"exceptions": list_check_exceptions(provider_id)}


@app.get("/api/providers/{provider_id}/custom-checks")
async def get_custom_checks(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"checks": list_custom_checks(provider_id)}


@app.post("/api/providers/{provider_id}/custom-checks")
async def create_custom_check(provider_id: str, request: CustomCheckRequest):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    item = save_custom_check(provider_id, request.model_dump())
    audit("check.custom.create", "provider", provider_id, provider_label(provider_id), f"{item['name']} · 대상 {item.get('target', '')} · {item.get('command', '')[:120]}")
    return item


@app.put("/api/providers/{provider_id}/custom-checks/{check_id}")
async def edit_custom_check(provider_id: str, check_id: str, request: CustomCheckRequest):
    if not any(item["id"] == check_id for item in list_custom_checks(provider_id)):
        raise HTTPException(404, "사용자 정의 점검을 찾을 수 없습니다.")
    item = save_custom_check(provider_id, request.model_dump(), check_id)
    audit("check.custom.update", "provider", provider_id, provider_label(provider_id), f"{item['name']} · 대상 {item.get('target', '')} · {item.get('command', '')[:120]}")
    return item


@app.delete("/api/providers/{provider_id}/custom-checks/{check_id}")
async def remove_custom_check(provider_id: str, check_id: str):
    existing = next((item for item in list_custom_checks(provider_id) if item["id"] == check_id), None)
    if not delete_custom_check(provider_id, check_id):
        raise HTTPException(404, "사용자 정의 점검을 찾을 수 없습니다.")
    audit("check.custom.delete", "provider", provider_id, provider_label(provider_id), existing["name"] if existing else check_id)
    return {"status": "deleted"}


async def execute_custom_check(provider: dict, nodes: list[dict], definition: dict, first_only: bool = False) -> dict:
    targets = [node for node in nodes if definition["target_role"] == "all" or node["role"] == definition["target_role"]]
    if definition["target_role"] == "active_controller":
        targets = [node for node in nodes if node["hostname"] == provider["controller_hostname"]]
    if first_only:
        targets = targets[:1]
    if not targets:
        return {"status": "unavailable", "result": "-", "note": "실행 대상 노드 없음", "details": [], "nodes": []}

    async def execute(node: dict) -> dict:
        options = provider_ssh_options(provider)
        options["known_hosts"] = provider_known_hosts(provider["id"])
        try:
            address = await resolve_node_address(node)
            async with asyncssh.connect(address, **options) as connection:
                command = definition["command"]
                if definition.get("execution_context") == "openstack":
                    safe_command = " ".join(shlex.quote(part) for part in validate_custom_command(command))
                    command = """openrc=''; for candidate in /root/contrabass-openrc \"$HOME/contrabass-openrc\"; do if [ -r \"$candidate\" ]; then openrc=\"$candidate\"; break; fi; done; if [ -z \"$openrc\" ]; then echo 'OpenStack OpenRC 파일을 찾을 수 없습니다.' >&2; exit 78; fi; . \"$openrc\" >/dev/null 2>&1 || { echo 'OpenStack OpenRC 적용에 실패했습니다.' >&2; exit 78; }; """ + safe_command
                response = await run_as_root(connection, provider, command, definition["timeout_seconds"])
            output = (response.stdout + response.stderr).strip()[:20000]
            if response.exit_status != 0:
                state = "unavailable"
            elif definition["rule_type"] == "contains":
                state = "healthy" if definition["expected_value"] in output else "warning"
            elif definition["rule_type"] == "not_contains":
                state = "warning" if definition["expected_value"] in output else "healthy"
            else:
                state = "healthy"
            return {"hostname": node["hostname"], "role": node["role"], "status": state, "output": output or "출력 없음"}
        except PrivilegeError as exc:
            return {"hostname": node["hostname"], "role": node["role"], "status": "unavailable", "output": f"root 권한 획득 실패: {exc}"}
        except (asyncssh.Error, OSError, TimeoutError) as exc:
            return {"hostname": node["hostname"], "role": node["role"], "status": "unavailable", "output": node_failure_reason(exc)}

    results = await asyncio.gather(*(execute(node) for node in targets))
    status = "warning" if any(item["status"] == "warning" for item in results) else ("unavailable" if any(item["status"] == "unavailable" for item in results) else "healthy")
    healthy = sum(item["status"] == "healthy" for item in results)
    return {
        "status": status, "result": f"{healthy}/{len(results)}대 정상", "note": definition["description"] or "사용자 정의 SSH 점검",
        "details": [{"title": f"{item['hostname']} ({item['role']})", "output": item["output"]} for item in results], "nodes": results,
    }


@app.post("/api/providers/{provider_id}/custom-checks/test")
async def test_custom_check(provider_id: str, request: CustomCheckRequest):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    if not nodes:
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
    audit("check.custom.test", "provider", provider_id, provider["name"], f"{request.name} · {request.command[:120]}")
    return await execute_custom_check(provider, nodes, request.model_dump(), True)


@app.post("/api/providers/{provider_id}/check-exceptions")
async def create_check_exception(provider_id: str, request: CheckExceptionRequest):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    custom_keys = {item["key"] for item in list_custom_checks(provider_id)}
    if request.item_key not in CHECK_KEYS | custom_keys:
        raise HTTPException(400, "지원하지 않는 점검 항목입니다.")
    reason = request.reason.strip()
    if not reason:
        raise HTTPException(400, "예외 사유를 입력하세요.")
    node_hostname = request.node_hostname.strip()
    if node_hostname and node_hostname not in {node["hostname"] for node in list_provider_nodes(provider_id)}:
        raise HTTPException(400, "해당 공급자에 등록된 노드가 아닙니다.")
    exception = save_check_exception(provider_id, request.item_key, reason, node_hostname)
    audit("check.exception.create", "provider", provider_id, provider_label(provider_id), f"{request.item_key} · {node_hostname or '전체 노드'} · {reason[:200]}")
    return exception


@app.delete("/api/providers/{provider_id}/check-exceptions/{exception_id}")
async def remove_check_exception(provider_id: str, exception_id: str):
    existing = next((item for item in list_check_exceptions(provider_id) if item["id"] == exception_id), None)
    if not delete_check_exception(provider_id, exception_id):
        raise HTTPException(404, "예외 규칙을 찾을 수 없습니다.")
    audit("check.exception.delete", "provider", provider_id, provider_label(provider_id), f"{existing['item_key']} · {existing.get('node_hostname') or '전체 노드'}" if existing else exception_id)
    return {"status": "deleted"}


@app.get("/api/providers/{provider_id}/log-exclusions")
async def get_log_exclusions(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"exclusions": list_log_exclusions(provider_id), "services": list(LOG_SERVICES)}


@app.post("/api/providers/{provider_id}/log-exclusions")
async def create_log_exclusion(provider_id: str, request: LogExclusionRequest):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    service = request.service.strip()
    if service and service not in LOG_SERVICES:
        raise HTTPException(400, "지원하지 않는 로그 서비스입니다.")
    try:
        pattern = validate_log_pattern(request.pattern)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    reason = request.reason.strip()
    if not reason:
        raise HTTPException(400, "제외 사유를 입력하세요.")
    exclusion = save_log_exclusion(provider_id, service, pattern, reason)
    audit("check.log_exclusion.create", "provider", provider_id, provider_label(provider_id), f"{service or '전체 로그'} · {pattern[:150]} · {reason[:150]}")
    return exclusion


@app.delete("/api/providers/{provider_id}/log-exclusions/{exclusion_id}")
async def remove_log_exclusion(provider_id: str, exclusion_id: str):
    existing = next((item for item in list_log_exclusions(provider_id) if item["id"] == exclusion_id), None)
    if not delete_log_exclusion(provider_id, exclusion_id):
        raise HTTPException(404, "제외 패턴을 찾을 수 없습니다.")
    audit("check.log_exclusion.delete", "provider", provider_id, provider_label(provider_id), f"{existing['service'] or '전체 로그'} · {existing['pattern'][:150]}" if existing else exclusion_id)
    return {"status": "deleted"}


@app.get("/api/settings/inspection")
async def get_inspection_settings():
    return {"timeouts": INSPECTION_TIMEOUTS, "node_concurrency": RUNTIME["node_concurrency"], "timezone": str(schedule_timezone()),
            "retention": RETENTION_POLICY, "storage": check_storage_stats()}


class SettingUpdateRequest(BaseModel):
    value: dict


@app.get("/api/settings")
async def get_all_settings(request: Request):
    username = request.state.user["username"] if request.state.user else None
    return {"settings": {key: setting_snapshot(key, username) for key in SETTING_SPECS}, "timezones": COMMON_TIMEZONES,
            "storage": check_storage_stats(), "env_defaults": ENV_DEFAULTS}


@app.get("/api/settings/{key}")
async def get_setting_value(key: str, request: Request):
    if key not in SETTING_SPECS:
        raise HTTPException(404, "지원하지 않는 설정 항목입니다.")
    return setting_snapshot(key, request.state.user["username"] if request.state.user else None)


@app.put("/api/settings/{key}")
async def update_setting(key: str, payload: SettingUpdateRequest, request: Request):
    if key not in SETTING_SPECS:
        raise HTTPException(404, "지원하지 않는 설정 항목입니다.")
    if key == "inspection.timeouts" and any(progress.get("running") for progress in CHECK_PROGRESS.values()):
        raise HTTPException(409, "점검이 실행 중입니다. 완료 후 제한 시간을 변경하세요.")
    value = validate_setting(key, payload.value)
    username = request.state.user["username"] if request.state.user else None
    set_setting(setting_storage_key(key, username), value, username or "")
    apply_setting(key, value)
    snapshot = setting_snapshot(key, username)
    if not SETTING_SPECS[key].get("per_user"):
        audit("settings.update", "setting", key, SETTING_SPECS[key]["label"], json.dumps(value, ensure_ascii=False))
    return snapshot


@app.delete("/api/settings/{key}")
async def reset_setting(key: str, request: Request):
    if key not in SETTING_SPECS:
        raise HTTPException(404, "지원하지 않는 설정 항목입니다.")
    username = request.state.user["username"] if request.state.user else None
    delete_setting(setting_storage_key(key, username))
    apply_setting(key, ENV_DEFAULTS[key])
    if not SETTING_SPECS[key].get("per_user"):
        audit("settings.reset", "setting", key, SETTING_SPECS[key]["label"], "환경 변수 기본값으로 복원")
    return setting_snapshot(key, username)


@app.get("/api/providers/{provider_id}/settings")
async def get_provider_settings(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"provider_id": provider_id, "settings": {name: provider_setting_snapshot(provider_id, name) for name in PROVIDER_SETTING_SPECS}}


@app.get("/api/providers/{provider_id}/settings/{name}")
async def get_provider_setting(provider_id: str, name: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if name not in PROVIDER_SETTING_SPECS:
        raise HTTPException(404, "지원하지 않는 공급자 설정입니다.")
    return provider_setting_snapshot(provider_id, name)


@app.put("/api/providers/{provider_id}/settings/{name}")
async def update_provider_setting(provider_id: str, name: str, payload: SettingUpdateRequest, request: Request):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    value = validate_provider_setting(provider_id, name, payload.value)
    username = request.state.user["username"] if request.state.user else ""
    set_setting(provider_setting_key(provider_id, name), value, username)
    audit("provider.settings.update", "provider", provider_id, provider_label(provider_id), f"{PROVIDER_SETTING_SPECS[name]['label']} · {json.dumps(value, ensure_ascii=False)[:500]}")
    return provider_setting_snapshot(provider_id, name)


@app.delete("/api/providers/{provider_id}/settings/{name}")
async def reset_provider_setting(provider_id: str, name: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if name not in PROVIDER_SETTING_SPECS:
        raise HTTPException(404, "지원하지 않는 공급자 설정입니다.")
    delete_setting(provider_setting_key(provider_id, name))
    audit("provider.settings.reset", "provider", provider_id, provider_label(provider_id), PROVIDER_SETTING_SPECS[name]["label"])
    return provider_setting_snapshot(provider_id, name)


@app.get("/api/audit-logs")
async def get_audit_logs(limit: int = Query(50, ge=1, le=500), offset: int = Query(0, ge=0), actor: str = "", action: str = "", target_type: str = "",
                         target_id: str = "", outcome: str = "", search: str = "", since: str = "", until: str = ""):
    result = list_audit_logs(limit, offset, actor.strip(), action.strip(), target_type.strip(), target_id.strip(), outcome.strip(), search.strip()[:200], since.strip(), until.strip())
    for item in result["items"]:
        item["action_label"] = AUDIT_ACTION_LABELS.get(item["action"], item["action"])
    return result


@app.get("/api/audit-logs/facets")
async def get_audit_log_facets(days: int = Query(30, ge=1, le=3650)):
    facets = audit_log_facets(days)
    facets["actions"] = [{**item, "label": AUDIT_ACTION_LABELS.get(item["action"], item["action"])} for item in facets["actions"]]
    return {**facets, "retention_days": RUNTIME["audit_max_age_days"], "labels": AUDIT_ACTION_LABELS}


@app.post("/api/settings/retention/prune")
async def run_retention_prune():
    if any(progress.get("running") for progress in CHECK_PROGRESS.values()):
        raise HTTPException(409, "점검이 실행 중입니다. 완료 후 정리를 실행하세요.")
    result = await asyncio.to_thread(prune_check_results, **RETENTION_POLICY)
    audit_pruned = await asyncio.to_thread(prune_audit_logs, RUNTIME["audit_max_age_days"])
    logger.info("Inspection retention prune: %s (audit logs pruned: %d)", result, audit_pruned)
    audit("retention.prune", "retention", "", "점검 이력 보관 정책", f"삭제 {result.get('deleted', 0)}건 · 원본 정리 {result.get('compacted', 0)}건 · 감사 로그 {audit_pruned}건")
    return {**result, "audit_pruned": audit_pruned, "storage": check_storage_stats()}


def parse_openstack_table(output: str) -> tuple[list[str], list[dict]]:
    """Rows of an `openstack ... -f table` output as dicts keyed by header; ([], []) when there is no table."""
    lines = [line.rstrip() for line in output.splitlines() if line.lstrip().startswith("|")]
    if not lines:
        return [], []
    headers = [cell.strip() for cell in lines[0].strip().strip("|").split("|")]
    rows = []
    for line in lines[1:]:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != len(headers):
            continue
        rows.append(dict(zip(headers, cells)))
    return headers, rows


def describe_age(timestamp: str) -> str:
    """Relative age of an OpenStack 'Updated At' value, e.g. '2일 3시간 전'."""
    try:
        moment = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError:
        return ""
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    delta = datetime.now(timezone.utc) - moment
    minutes = int(delta.total_seconds() // 60)
    if minutes < 1:
        return "방금"
    if minutes < 60:
        return f"{minutes}분 전"
    hours, minutes = divmod(minutes, 60)
    if hours < 24:
        return f"{hours}시간 {minutes}분 전"
    days, hours = divmod(hours, 24)
    return f"{days}일 {hours}시간 전"


SERVICE_LIST_KEYS = {"cinder": "Cinder", "manila": "Manila", "nova": "Nova", "heat": "Heat"}
AGENT_LIST_KEYS = {"neutron": "Neutron", "network": "Neutron"}
RESOURCE_LIST_KEYS = {"vm": "인스턴스", "volume": "볼륨", "snapshot": "스냅샷", "share": "Share", "lb": "Load Balancer", "amphora": "Amphora", "heat_stack": "Stack"}
RESOURCE_BAD_STATUS = {"vm": {"ERROR"}, "volume": {"error", "error_deleting", "error_restoring", "error_extending"},
                       "snapshot": {"error", "error_deleting", "creating"}, "share": {"error", "error_deleting", "creating"},
                       "lb": {"ERROR"}, "amphora": {"ERROR"}, "heat_stack": {"CREATE_FAILED", "UPDATE_FAILED", "DELETE_FAILED", "ROLLBACK_FAILED", "ROLLBACK_COMPLETE"}}


def describe_cluster_item(key: str, status: str, count: int, output: str, rc: int, duration_ms: int, controller_hostname: str, controller_target: str) -> dict:
    """Turn the raw controller-side verdict into a result with counts, offending entries and a plain-language note."""
    item = {"status": status, "result": f"{count}건", "note": "활성 Controller 기준", "details": [{"title": controller_hostname, "output": output or "출력 없음"}]}
    if duration_ms:
        item["duration_seconds"] = round(duration_ms / 1000, 1)
    lowered = output.lower()
    if rc == 124:
        return {**item, "status": "unavailable", "result": "-", "note": f"명령 제한 시간 {INSPECTION_TIMEOUTS['openstack']}초 초과 · API 응답 지연 또는 VIP 장애 확인"}
    if rc == 127 or "command not found" in lowered:
        return {**item, "status": "unavailable", "result": "-", "note": f"명령을 찾을 수 없음 ({output.strip().splitlines()[-1][:80] if output.strip() else 'command not found'}) · CLI 설치 또는 PATH 확인"}
    if "is not an openstack command" in lowered:
        label = SERVICE_LIST_KEYS.get(key) or RESOURCE_LIST_KEYS.get(key) or key
        return {**item, "status": "unavailable", "result": "-", "note": f"{label} CLI 플러그인 미설치 · 서비스가 배포되지 않았을 가능성"}
    if rc != 0 and ("publicurl endpoint" in lowered or "endpoint for" in lowered and "not found" in lowered or "service catalog" in lowered):
        return {**item, "status": "unavailable", "result": "-", "note": "서비스 Endpoint 없음 · Keystone 카탈로그에 등록되지 않은 서비스"}
    if rc != 0 and ("unauthorized" in lowered or "401" in lowered or "authentication" in lowered):
        return {**item, "status": "unavailable", "result": "-", "note": "OpenStack 인증 실패 · OpenRC 자격 증명 확인"}
    if rc != 0 and ("connection refused" in lowered or "unable to establish connection" in lowered or "gateway" in lowered or "503" in lowered):
        return {**item, "status": "unavailable", "result": "-", "note": "API 연결 실패 · Endpoint 또는 HAProxy 상태 확인"}
    headers, rows = parse_openstack_table(output)
    if key in SERVICE_LIST_KEYS and rc == 0:
        label = SERVICE_LIST_KEYS[key]
        if not rows:
            return {**item, "status": "unavailable", "result": "서비스 0개", "note": f"등록된 {label} 서비스 없음 · 서비스 미배포 또는 API 조회 결과 없음"}
        if "Binary" not in headers:
            return {**item, "result": f"{len(rows)}행"}
        down = [row for row in rows if row.get("State", "").lower() == "down"]
        disabled = [row for row in rows if row.get("Status", "").lower() == "disabled"]
        stale = []
        for row in rows:
            age = describe_age(row.get("Updated At", ""))
            if age.endswith("일 전") or "일 " in age:
                stale.append(row)
        problems = []
        for row in down:
            age = describe_age(row.get("Updated At", ""))
            problems.append(f"{row.get('Binary')} {row.get('Host')} down" + (f" (마지막 갱신 {age})" if age else ""))
        for row in disabled:
            if row in down:
                continue
            reason = row.get("Disabled Reason") or ""
            problems.append(f"{row.get('Binary')} {row.get('Host')} disabled" + (f" ({reason})" if reason else ""))
        binaries = Counter(row.get("Binary", "") for row in rows)
        composition = " · ".join(f"{name} {number}" for name, number in sorted(binaries.items()))
        item["status"] = "warning" if problems else "healthy"
        item["result"] = f"서비스 {len(rows)}개 · Down {len(down)} · Disabled {len(disabled)}" if problems else f"서비스 {len(rows)}개 모두 정상"
        item["note"] = ("; ".join(problems) if problems else f"{composition} · 전체 up/enabled") + f" · 활성 Controller {controller_hostname}"
        item["problems"] = problems
        return item
    if key in AGENT_LIST_KEYS and rc == 0 and rows and "Alive" in headers:
        dead = [row for row in rows if ":-)" not in row.get("Alive", "")]
        down = [row for row in rows if row.get("State", "").upper() == "DOWN"]
        problems = [f"{row.get('Agent Type')} {row.get('Host')} {'응답 없음' if row in dead else 'admin down'}" for row in rows if row in dead or row in down]
        types = Counter(row.get("Agent Type", "") for row in rows)
        item["status"] = "warning" if problems else "healthy"
        item["result"] = f"에이전트 {len(rows)}개 · 응답 없음 {len(dead)} · Down {len(down)}" if problems else f"에이전트 {len(rows)}개 모두 정상"
        item["note"] = ("; ".join(problems[:8]) + (" 외" if len(problems) > 8 else "") if problems else " · ".join(f"{name} {number}" for name, number in sorted(types.items()))) + f" · 활성 Controller {controller_hostname}"
        item["problems"] = problems
        return item
    if key in RESOURCE_LIST_KEYS and rc == 0:
        label = RESOURCE_LIST_KEYS[key]
        if not rows:
            return {**item, "status": "healthy", "result": f"{label} 0건", "note": f"등록된 {label} 없음 · 활성 Controller {controller_hostname}"}
        status_column = next((column for column in ("Status", "Stack Status", "Provisioning Status") if column in headers), None)
        if not status_column:
            return {**item, "result": f"{label} {len(rows)}건"}
        bad_states = RESOURCE_BAD_STATUS.get(key, set())
        bad = [row for row in rows if row.get(status_column, "") in bad_states]
        by_status = Counter(row.get(status_column, "") for row in rows)
        listed = [f"{row.get('Name') or row.get('Stack Name') or row.get('ID', '')[:8]} ({row.get(status_column)})" for row in bad[:6]]
        item["status"] = "warning" if bad else "healthy"
        item["result"] = f"{label} {len(rows)}건 · 이상 {len(bad)}건" if bad else f"{label} {len(rows)}건 모두 정상"
        item["note"] = ("; ".join(listed) + (f" 외 {len(bad) - 6}건" if len(bad) > 6 else "") if bad else " · ".join(f"{name} {number}" for name, number in sorted(by_status.items()))) + f" · 활성 Controller {controller_hostname}"
        item["problems"] = listed
        return item
    if rows and rc == 0:
        item["result"] = f"{len(rows)}행"
    return item


@app.post("/api/providers/{provider_id}/checks")
async def run_provider_check(provider_id: str, request: CheckRequest | None = None, trigger: str = "manual"):
    """Run one inspection per provider at a time and always leave a terminal progress state behind."""
    if CHECK_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "이미 이 공급자의 일일점검이 실행 중입니다. 완료 후 다시 실행하세요.")
    started = datetime.now(timezone.utc)
    action = "check.scheduled" if trigger == "scheduled" else "check.run"
    item_count = len(request.selected_items) if request and request.selected_items is not None else None
    # The inspection runs as its own task so the cancel route can stop it; the HTTP request just waits for it.
    task = asyncio.create_task(execute_provider_check(provider_id, request, trigger, started))
    CHECK_TASKS[provider_id] = task
    try:
        outcome = await asyncio.shield(task)
    except asyncio.CancelledError:
        if task.cancelled() or task.done():
            CHECK_PROGRESS[provider_id] = {"running": False, "stage": "cancelled", "message": "운영자가 점검을 취소했습니다.", "current_items": [], "percent": 0,
                                           "started_at": started.isoformat(), "updated_at": datetime.now(timezone.utc).isoformat(), "trigger": trigger}
            audit(action, "provider", provider_id, provider_label(provider_id), "운영자 취소", outcome="failure")
            raise HTTPException(409, "점검이 취소되었습니다.")
        raise
    except HTTPException as exc:
        if CHECK_PROGRESS.get(provider_id, {}).get("running"):
            CHECK_PROGRESS[provider_id] = {"running": False, "stage": "failed", "message": f"점검 실패: {exc.detail}", "current_items": [], "percent": 0,
                                           "started_at": started.isoformat(), "updated_at": datetime.now(timezone.utc).isoformat()}
        audit(action, "provider", provider_id, provider_label(provider_id), str(exc.detail), outcome="failure")
        raise
    except Exception as exc:
        CHECK_PROGRESS[provider_id] = {"running": False, "stage": "failed", "message": f"점검 실패: {type(exc).__name__}", "current_items": [], "percent": 0,
                                       "started_at": started.isoformat(), "updated_at": datetime.now(timezone.utc).isoformat()}
        audit(action, "provider", provider_id, provider_label(provider_id), type(exc).__name__, outcome="failure")
        raise HTTPException(500, f"점검 실행 중 오류가 발생했습니다: {type(exc).__name__}") from exc
    finally:
        if CHECK_TASKS.get(provider_id) is task:
            CHECK_TASKS.pop(provider_id, None)
    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    audit(action, "provider", provider_id, provider_label(provider_id),
          f"결과 {outcome.get('status')} · 항목 {item_count if item_count is not None else '전체'} · {elapsed:.0f}초 · 점검 ID {outcome.get('check_id')}")
    return outcome


@app.post("/api/providers/{provider_id}/checks/cancel")
async def cancel_provider_check(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    task = CHECK_TASKS.get(provider_id)
    if not task or task.done() or not CHECK_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "실행 중인 점검이 없습니다.")
    task.cancel()
    CHECK_PROGRESS[provider_id] = {**CHECK_PROGRESS.get(provider_id, {}), "running": True, "stage": "cancelling", "message": "점검을 취소하고 있습니다. 실행 중인 SSH 명령이 끝나는 대로 멈춥니다.", "updated_at": datetime.now(timezone.utc).isoformat()}
    return {"status": "cancelling"}


async def execute_provider_check(provider_id: str, request: CheckRequest | None, trigger: str, started: datetime):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    all_nodes = list_provider_nodes(provider_id)
    nodes = [node for node in all_nodes if not node.get("maintenance")]
    maintenance_nodes = [node["hostname"] for node in all_nodes if node.get("maintenance")]
    if not all_nodes:
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
    if not nodes:
        raise HTTPException(409, "모든 노드가 정비 중으로 표시되어 점검할 노드가 없습니다.")
    custom_definitions = {item["key"]: item for item in list_custom_checks(provider_id) if item["enabled"]}
    available_keys = CHECK_KEYS | set(custom_definitions)
    selected_items = set(request.selected_items) if request and request.selected_items is not None else set(available_keys)
    invalid_items = selected_items - available_keys
    if invalid_items:
        raise HTTPException(400, f"지원하지 않는 점검 항목: {', '.join(sorted(invalid_items))}")
    if not selected_items:
        raise HTTPException(400, "점검할 항목을 하나 이상 선택하세요.")
    previous_check = latest_check(provider_id)
    node_check_keys = {
        "cpu", "memory", "disk", "chrony", "bonding", "mount", "nova_compute", "virtualization",
        "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration", "libvirt_state",
        "instance_storage", "smart_health", "raid_health", "nova_log", "neutron_log", "cinder_log",
        "glance_log", "manila_log", "octavia_log", "masakari_log", "swift_log", "heat_log", "system_log",
    }
    # Per-node state shared by reference with the progress dict, so check_node can flip it in place.
    node_states: dict[str, dict] = {node["hostname"]: {"role": node["role"], "state": "pending", "seconds": None} for node in nodes}
    def update_progress(stage: str, message: str, current_items: set[str] | list[str], percent: int, running: bool = True):
        CHECK_PROGRESS[provider_id] = {
            "running": running, "stage": stage, "message": message, "current_items": sorted(current_items),
            "percent": percent, "updated_at": datetime.now(timezone.utc).isoformat(), "started_at": started.isoformat(), "trigger": trigger,
            "nodes": node_states, "node_total": len(nodes), "node_done": sum(1 for state in node_states.values() if state["state"] in {"done", "failed"}),
        }
    update_progress("preparing", "점검 대상과 SSH 연결을 준비하고 있습니다.", selected_items, 5)
    thresholds = provider_setting(provider_id, "thresholds")
    selected_shell = shlex.quote("|" + "|".join(sorted(selected_items)) + "|")
    # Provider-specific log exclusion patterns: '' applies to every service, otherwise one service.
    exclusion_rules = list_log_exclusions(provider_id)
    exclusion_lines = ["exclude_dir=$(mktemp -d 2>/dev/null || echo /tmp/.okestro-exclude-$$)", 'mkdir -p "$exclude_dir"']
    for service in LOG_SERVICES:
        patterns = [rule["pattern"] for rule in exclusion_rules if rule["service"] in ("", service)]
        if patterns:
            exclusion_lines.append(f"printf '%s\\n' {' '.join(shlex.quote(pattern) for pattern in patterns)} > \"$exclude_dir/{service}\"")
    timeouts_shell = f"T_CMD={INSPECTION_TIMEOUTS['command']}\nT_LOG={INSPECTION_TIMEOUTS['log_scan']}\n"

    node_command = f"SELECTED_ITEMS={selected_shell}\n{timeouts_shell}" + "\n".join(exclusion_lines) + "\n" + r'''
LC_ALL=C
script_started=$(date +%s%3N 2>/dev/null || date +%s000)
now_ms() { date +%s%3N 2>/dev/null || date +%s000; }
wanted() { case "$SELECTED_ITEMS" in *"|$1|"*) return 0;; *) return 1;; esac; }
emit_raw() { raw_key="$1"; shift; wanted "$raw_key" || return; raw_output=$(timeout -k 3 "$T_CMD" "$@" </dev/null 2>&1); raw_encoded=$(printf '%s' "$raw_output" | base64 -w0 2>/dev/null); printf '%s_raw=%s\n' "$raw_key" "$raw_encoded"; }
emit_node_check() { check_key="$1"; check_command="$2"; bad_pattern="$3"; wanted "$check_key" || return; t0=$(now_ms); check_output=$(timeout -k 3 "$T_CMD" bash -c "$check_command" </dev/null 2>&1); check_rc=$?; t1=$(now_ms); if [ $check_rc -eq 124 ]; then check_state=unavailable; check_output=$(printf '명령 제한 시간 %s초 초과\n%s' "$T_CMD" "$check_output"); elif [ $check_rc -ne 0 ]; then check_state=unavailable; elif [ -n "$bad_pattern" ] && printf '%s\n' "$check_output" | grep -Eiq "$bad_pattern"; then check_state=warning; else check_state=healthy; fi; check_encoded=$(printf '%s' "$check_output" | base64 -w0 2>/dev/null); printf '%s=%s\n%s_raw=%s\n%s_ms=%s\n%s_rc=%s\n' "$check_key" "$check_state" "$check_key" "$check_encoded" "$check_key" "$((t1-t0))" "$check_key" "$check_rc"; }
printf 'hostname=%s\n' "$(hostname -s)"
printf 'uptime_seconds=%s\n' "$(cut -d. -f1 /proc/uptime)"
printf 'cpu_cores=%s\n' "$(getconf _NPROCESSORS_ONLN)"
timeout -k 3 "$T_CMD" top -bn1 </dev/null 2>/dev/null | awk '/Cpu\(s\)|%Cpu/{for(i=1;i<=NF;i++)if($i ~ /id/){gsub(/[^0-9.]/,"",$(i-1)); printf "cpu_used_percent=%.1f\n",100-$(i-1); exit}}'
awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2}END{printf "memory_total_kb=%s\nmemory_used_kb=%s\n",t,t-a}' /proc/meminfo
timeout -k 3 "$T_CMD" df -Pk / </dev/null | awk 'NR==2{gsub(/%/,"",$5); printf "disk_total_kb=%s\ndisk_used_kb=%s\ndisk_used_percent=%s\n",$2,$3,$5}'
if command -v chronyc >/dev/null 2>&1; then timeout -k 3 "$T_CMD" chronyc tracking </dev/null >/dev/null 2>&1 && echo chrony=healthy || echo chrony=warning; else echo chrony=unavailable; fi
# Bonding: evaluated only where a bond exists (nodes without /proc/net/bonding are reported as not configured,
# not as a failure). A bond or slave whose MII status is not "up" is a warning.
if wanted bonding; then
  if [ -d /proc/net/bonding ] && ls /proc/net/bonding/* >/dev/null 2>&1; then
    bond_state=healthy; bond_lines=""
    for bond_file in /proc/net/bonding/*; do
      bond_name=$(basename "$bond_file")
      bond_mode=$(awk -F': ' '/^Bonding Mode/{print $2; exit}' "$bond_file")
      bond_mii=$(awk -F': ' '/^MII Status/{print $2; exit}' "$bond_file")
      bond_slaves=$(awk -F': ' '/^Slave Interface/{name=$2} /^MII Status/ && name!=""{printf "%s:%s ", name, $2; name=""}' "$bond_file")
      [ "$bond_mii" = up ] || bond_state=warning
      case " $bond_slaves" in *:down*|*:going*) bond_state=warning;; esac
      [ -n "$bond_slaves" ] || bond_state=warning
      bond_lines="${bond_lines}${bond_name}|${bond_mode}|${bond_mii}|${bond_slaves% }"$'\n'
    done
    echo "bonding=$bond_state"; printf 'bonding_summary=%s\n' "$(printf '%s' "$bond_lines" | base64 -w0)"
  else
    echo bonding=not_configured
  fi
fi
# Mount (Controller role): warning when an fstab entry under /var/lib/{glance,cinder,nova} is not mounted or a
# network mount there does not answer within 5 s. Cinder NFS shares are mounted lazily by the active cinder-volume,
# so an unmounted share by itself is informational.
if wanted mount; then
  if command -v findmnt >/dev/null 2>&1; then
    mount_state=healthy
    mounted=$(timeout -k 3 "$T_CMD" findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS </dev/null 2>/dev/null | grep -E '^/var/lib/(glance|cinder|nova)' || true)
    fstab_missing=$(timeout -k 3 "$T_CMD" findmnt -rn --fstab -o TARGET </dev/null 2>/dev/null | grep -E '^/var/lib/(glance|cinder|nova)' | while read -r target; do findmnt -rn "$target" >/dev/null 2>&1 || echo "$target"; done)
    stale=$(printf '%s\n' "$mounted" | awk '$3 ~ /^(nfs|nfs4|cifs|fuse\.glusterfs|glusterfs|ceph)$/{print $1}' | while read -r target; do timeout 5 stat -f "$target" >/dev/null 2>&1 || echo "$target"; done)
    nfs_shares_file=$(grep -hEs '^[[:space:]]*nfs_shares_config[[:space:]]*=' /etc/cinder/cinder.conf /etc/cinder/cinder.conf.d/*.conf 2>/dev/null | tail -n1 | sed 's/^[^=]*=[[:space:]]*//')
    nfs_shares=0; [ -n "$nfs_shares_file" ] && [ -r "$nfs_shares_file" ] && nfs_shares=$(grep -cvE '^[[:space:]]*(#|$)' "$nfs_shares_file")
    glance_fs=$(findmnt -rn -T /var/lib/glance/images -o TARGET,FSTYPE 2>/dev/null | head -n1)
    [ -n "$fstab_missing" ] && mount_state=warning
    [ -n "$stale" ] && mount_state=warning
    echo "mount=$mount_state"
    printf 'mount_summary=%s\n' "$(printf 'mounted=%s\nfstab_missing=%s\nstale=%s\nnfs_shares=%s\nglance=%s\n' "$(printf '%s' "$mounted" | tr '\n' ';')" "$(printf '%s' "$fstab_missing" | tr '\n' ';')" "$(printf '%s' "$stale" | tr '\n' ';')" "$nfs_shares" "$glance_fs" | base64 -w0)"
  else
    echo mount=unavailable
  fi
fi
if systemctl is-active --quiet openstack-nova-compute </dev/null 2>/dev/null || systemctl is-active --quiet nova-compute </dev/null 2>/dev/null || pgrep -f '[n]ova-compute' </dev/null >/dev/null 2>&1; then echo nova_compute=healthy; else echo nova_compute=warning; fi
emit_raw cpu sh -c 'top -bn1 | head -n 12'
emit_raw memory free -h
emit_raw disk df -h /
emit_raw chrony sh -c 'chronyc sources -v; echo; chronyc tracking'
if [ -d /proc/net/bonding ]; then emit_raw bonding sh -c 'cat /proc/net/bonding/*'; else echo bonding_raw=; fi
emit_raw mount sh -c 'findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null | grep -E "TARGET|/var/lib/(glance|cinder|nova)" || mount | grep -E "/var/lib/(glance|cinder|nova)" || echo "OpenStack 데이터 경로 마운트 없음 (로컬 디스크)"'
emit_raw nova_compute sh -c 'systemctl --no-pager -l status openstack-nova-compute nova-compute 2>&1 || pgrep -af nova-compute || true'
emit_node_check virtualization 'printf "type="; systemd-detect-virt 2>/dev/null || echo none; printf "chassis="; cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo unknown' ''
emit_node_check failed_units 'systemctl --failed --no-legend --no-pager' '.+'
emit_node_check kernel_errors 'dmesg --level=err,crit,alert,emerg --ctime | tail -n 100' '.+'
emit_node_check nic_state 'ip -br link' ' (DOWN|NO-CARRIER) '
emit_node_check ovs_state 'command -v ovs-vsctl >/dev/null 2>&1 && ovs-vsctl show' 'error|failed'
emit_node_check kvm_acceleration 'printf "acceleration_flags="; egrep -c "(vmx|svm)" /proc/cpuinfo; lsmod | grep -E "^kvm" || true' 'acceleration_flags=0'
emit_node_check libvirt_state 'virsh list --all' 'error|failed|shut off|paused|crashed'
emit_node_check instance_storage 'df -h /var/lib/nova/instances' ' 8[0-9]%| 9[0-9]%|100%'
virt_type=$(systemd-detect-virt 2>/dev/null || true)
if [ -n "$virt_type" ] && [ "$virt_type" != none ]; then
  if wanted smart_health; then echo smart_health=unavailable; printf 'smart_health_raw=%s\n' "$(printf '가상화 환경(%s): 물리 디스크 SMART 점검 제외' "$virt_type" | base64 -w0)"; fi
  if wanted raid_health; then echo raid_health=unavailable; printf 'raid_health_raw=%s\n' "$(printf '가상화 환경(%s): 물리 RAID 점검 제외' "$virt_type" | base64 -w0)"; fi
else
  emit_node_check smart_health 'command -v smartctl >/dev/null 2>&1 && { smartctl --scan; for disk in $(smartctl --scan | awk "{print \$1}"); do smartctl -H "$disk"; done; }' 'FAILED|failure|prefail'
  emit_node_check raid_health 'cat /proc/mdstat; command -v mdadm >/dev/null 2>&1 && mdadm --detail --scan || true' '\[[U_]*_[U_]*\]'
fi
scan_dir_logs() { for log_file in "$1"/*.log*; do [ -f "$log_file" ] || continue; case "$log_file" in *.gz) gzip -cd -- "$log_file" 2>/dev/null;; *) cat -- "$log_file" 2>/dev/null;; esac; done | awk -v iso="$2" -v syslog="$3" 'index($0,iso)==1 || index($0,syslog)==1' | grep -Ei "$4"; }
scan_file_logs() { awk -v iso="$2" -v syslog="$3" 'index($0,iso)==1 || index($0,syslog)==1' $1 2>/dev/null | grep -E "$4"; }
export -f scan_dir_logs scan_file_logs
# $1 service  $2 scanner  $3 source  $4 iso date  $5 syslog date  $6 pattern  $7 output file -> prints excluded count, returns scanner rc
collect_log_matches() {
  exclude_file="$exclude_dir/$1"
  timeout -k 3 "$T_LOG" bash -c "$2 \"\$@\"" _ "$3" "$4" "$5" "$6" </dev/null > "$7.all" 2>/dev/null; scan_rc=$?
  if [ -s "$exclude_file" ]; then grep -Eiv -f "$exclude_file" "$7.all" > "$7" 2>/dev/null; else cp "$7.all" "$7"; fi
  echo $(( $(grep -c . "$7.all") - $(grep -c . "$7") ))
  rm -f "$7.all"
  return $scan_rc
}
emit_service_log() {
  service="$1"; scanner="$2"; source="$3"; pattern="$4"
  yesterday_iso=$(date -d yesterday +%Y-%m-%d); yesterday_syslog=$(LC_ALL=C date -d yesterday '+%b %e')
  previous_iso=$(date -d '2 days ago' +%Y-%m-%d); previous_syslog=$(LC_ALL=C date -d '2 days ago' '+%b %e')
  work=$(mktemp); t0=$(now_ms)
  excluded=$(collect_log_matches "$service" "$scanner" "$source" "$yesterday_iso" "$yesterday_syslog" "$pattern" "$work"); scan_rc=$?
  count=$(grep -c . "$work"); sample=$(tail -n 100 "$work" | base64 -w0 2>/dev/null)
  previous_excluded=$(collect_log_matches "$service" "$scanner" "$source" "$previous_iso" "$previous_syslog" "$pattern" "$work"); previous_rc=$?
  previous_sample=$(tail -n 100 "$work" | base64 -w0 2>/dev/null)
  rm -f "$work"; t1=$(now_ms)
  if [ "$scan_rc" -eq 124 ]; then state=unavailable; elif [ "$count" -gt 0 ]; then state=warning; else state=healthy; fi
  printf '%s_log=%s\n%s_log_count=%s\n%s_log_excluded=%s\n%s_log_date=%s\n%s_previous_log_date=%s\n%s_log_sample=%s\n%s_previous_log_sample=%s\n%s_log_ms=%s\n%s_log_rc=%s\n' "$service" "$state" "$service" "$count" "$service" "$excluded" "$service" "$yesterday_iso" "$service" "$previous_iso" "$service" "$sample" "$service" "$previous_sample" "$service" "$((t1-t0))" "$service" "$scan_rc"
}
check_service_log() {
  service="$1"
  wanted "${service}_log" || return
  directory="/var/log/$service"
  if [ ! -d "$directory" ] || ! find "$directory" -maxdepth 1 -type f -name '*.log*' -print -quit 2>/dev/null | grep -q .; then
    printf '%s_log=unavailable\n%s_log_count=0\n' "$service" "$service"
    return
  fi
  emit_service_log "$service" scan_dir_logs "$directory" 'ERROR|CRITICAL|Traceback|Exception|Failed'
}
for service in nova neutron cinder glance manila octavia masakari swift heat; do check_service_log "$service"; done
if wanted system_log; then
  system_files=""
  for file in /var/log/syslog /var/log/messages; do [ -f "$file" ] && system_files="$system_files $file"; done
  if [ -z "$system_files" ]; then
    echo system_log=unavailable
    echo system_log_count=0
  else
    emit_service_log system scan_file_logs "$system_files" 'ERROR|CRITICAL|Traceback'
  fi
fi
rm -rf "$exclude_dir" 2>/dev/null
printf 'script_ms=%s\n' "$(( $(now_ms) - script_started ))"
'''

    node_semaphore = asyncio.Semaphore(RUNTIME["node_concurrency"])
    node_script_timeout = INSPECTION_TIMEOUTS["node_script"]

    async def check_node(node: dict) -> dict:
        options = provider_ssh_options(provider)
        options["known_hosts"] = provider_known_hosts(provider_id)
        node_started = datetime.now(timezone.utc)
        def mark_node(state: str) -> None:
            entry = node_states.get(node["hostname"])
            if entry is not None:
                entry["state"] = state
                entry["seconds"] = round((datetime.now(timezone.utc) - node_started).total_seconds(), 1)
                progress = CHECK_PROGRESS.get(provider_id)
                if progress:
                    progress["node_done"] = sum(1 for item in node_states.values() if item["state"] in {"done", "failed"})
                    progress["updated_at"] = datetime.now(timezone.utc).isoformat()
        try:
            address = await resolve_node_address(node)
            async with node_semaphore:
                mark_node("running")
                async with asyncssh.connect(address, **options) as connection:
                    # Each command inside the script has its own limit (INSPECTION_TIMEOUTS); this outer
                    # limit only guards against a wedged SSH session and is well above the sum of budgets
                    # that a normal run needs.
                    response = await run_as_root(connection, provider, node_command, node_script_timeout)
                    fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if response.exit_status != 0:
                raise RuntimeError("점검 명령 실패")
            values = {}
            for line in response.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    values[key] = value
            integer_keys = {"uptime_seconds", "cpu_cores", "memory_total_kb", "memory_used_kb", "disk_total_kb", "disk_used_kb", "disk_used_percent", "script_ms"}
            for service in LOG_SERVICES:
                integer_keys.update({f"{service}_log_count", f"{service}_log_excluded", f"{service}_log_ms", f"{service}_log_rc"})
            integer_keys.update(f"{key}_{suffix}" for key in ("virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration", "libvirt_state", "instance_storage", "smart_health", "raid_health") for suffix in ("ms", "rc"))
            for key in integer_keys:
                try: values[key] = int(values[key])
                except (KeyError, ValueError): pass
            for key in ("bonding_summary", "mount_summary"):
                encoded = values.pop(key, "")
                try: values[key] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: values[key] = ""
            try: values["cpu_used_percent"] = float(values["cpu_used_percent"])
            except (KeyError, ValueError): values["cpu_used_percent"] = None
            values["memory_used_percent"] = round(values.get("memory_used_kb", 0) / max(values.get("memory_total_kb", 1), 1) * 100, 1)
            for service in LOG_SERVICES:
                for sample_key in (f"{service}_log_sample", f"{service}_previous_log_sample"):
                    encoded = values.pop(sample_key, "")
                    try: values[sample_key] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                    except ValueError: values[sample_key] = ""
            for key in ("cpu", "memory", "disk", "chrony", "bonding", "mount", "nova_compute", "virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration", "libvirt_state", "instance_storage", "smart_health", "raid_health"):
                encoded = values.pop(f"{key}_raw", "")
                try: values[f"{key}_raw"] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: values[f"{key}_raw"] = ""
            # Log status comes from the node script as warning/healthy by "any error line"; re-judge it against the
            # provider's own error-count threshold so noisy sites can tolerate a known baseline.
            for service in LOG_SERVICES:
                count = values.get(f"{service}_log_count")
                if isinstance(count, int) and values.get(f"{service}_log") in {"warning", "healthy"}:
                    values[f"{service}_log"] = "warning" if count > 0 and count >= thresholds["log_error_warning"] else "healthy"
            warnings = []
            if "cpu" in selected_items and values.get("cpu_used_percent") is not None and values["cpu_used_percent"] >= thresholds["cpu_warning"]: warnings.append(f"CPU 사용률 {thresholds['cpu_warning']}% 이상")
            if "memory" in selected_items and values["memory_used_percent"] >= thresholds["memory_warning"]: warnings.append(f"메모리 사용률 {thresholds['memory_warning']}% 이상")
            if "disk" in selected_items and values.get("disk_used_percent", 0) >= thresholds["disk_warning"]: warnings.append(f"디스크 사용률 {thresholds['disk_warning']}% 이상")
            for key, label in (("chrony", "Chrony"), ("bonding", "Bonding"), ("mount", "Mount")):
                if key in selected_items and values.get(key) == "warning": warnings.append(f"{label} 상태 확인 필요")
            if "nova_compute" in selected_items and node["role"] == "compute" and values.get("nova_compute") == "warning": warnings.append("nova-compute 비정상")
            for service, label in (("nova", "Nova"), ("neutron", "Neutron"), ("cinder", "Cinder"), ("glance", "Glance"), ("manila", "Manila"), ("octavia", "Octavia"), ("masakari", "Masakari"), ("swift", "Swift"), ("heat", "Heat"), ("system", "System")):
                if values.get(f"{service}_log") == "warning":
                    warnings.append(f"{label} 로그 오류 {values.get(f'{service}_log_count', 0)}건")
            duration = round((datetime.now(timezone.utc) - node_started).total_seconds(), 1)
            mark_node("done")
            return {**node, "address": address, "reachable": True, "fingerprint": fingerprint, "status": "warning" if warnings else "healthy", "metrics": values, "warnings": warnings,
                    "duration_seconds": duration, "script_seconds": round(values.get("script_ms", 0) / 1000, 1) if isinstance(values.get("script_ms"), int) else None}
        except (asyncssh.Error, OSError, RuntimeError) as exc:
            if isinstance(exc, TimeoutError):
                reason = f"점검 명령이 {node_script_timeout}초 안에 완료되지 않음"
            else:
                reason = node_failure_reason(exc)
            duration = round((datetime.now(timezone.utc) - node_started).total_seconds(), 1)
            mark_node("failed")
            return {**node, "reachable": False, "status": "warning", "metrics": {}, "warnings": [f"SSH 점검 실패: {reason}"], "duration_seconds": duration}

    node_items = selected_items & node_check_keys
    update_progress("nodes", f"전체 노드 {len(nodes)}대의 시스템·서비스·로그를 점검하고 있습니다.", node_items, 20)
    nodes_started = datetime.now(timezone.utc)
    node_results = await asyncio.gather(*(check_node(node) for node in nodes))
    nodes_seconds = round((datetime.now(timezone.utc) - nodes_started).total_seconds(), 1)
    selected_custom = {key: value for key, value in custom_definitions.items() if key in selected_items}
    custom_items = {}
    if selected_custom:
        update_progress("custom", "사용자 정의 점검을 실행하고 있습니다.", set(selected_custom), 60)
        custom_results = await asyncio.gather(*(execute_custom_check(provider, nodes, definition) for definition in selected_custom.values()))
        custom_items = dict(zip(selected_custom, custom_results))

    controller_items = selected_items - node_check_keys
    update_progress("openstack", "활성 Controller에서 클러스터와 OpenStack 항목을 점검하고 있습니다.", controller_items, 65)
    database_credentials = provider.get("database_credentials")
    mysql_defaults_path = f"/tmp/.okestro-mysql-{uuid.uuid4().hex}.cnf" if database_credentials else ""
    controller_command = f"SELECTED_ITEMS={selected_shell}\nMYSQL_DEFAULTS_FILE={shlex.quote(mysql_defaults_path)}\nPROVIDER_VIP={shlex.quote(provider['vip'])}\nT_OS={INSPECTION_TIMEOUTS['openstack']}\n" + r'''
LC_ALL=C
export MYSQL_DEFAULTS_FILE PROVIDER_VIP
now_ms() { date +%s%3N 2>/dev/null || date +%s000; }
wanted() { case "$SELECTED_ITEMS" in *"|$1|"*) return 0;; *) return 1;; esac; }
for candidate in /root/contrabass-openrc "$HOME/contrabass-openrc"; do [ -r "$candidate" ] && . "$candidate" >/dev/null 2>&1 && break; done
mysql_query() { if [ -n "$MYSQL_DEFAULTS_FILE" ]; then mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE" "$@"; else mysql "$@"; fi; }
export -f mysql_query
# stdin is the script itself (bash -s): children must never read it, or they swallow the rest of the script (rabbitmqctl does).
run_limited() { timeout -k 5 "$T_OS" bash -c "$1" </dev/null 2>&1; }
emit_check() { key="$1"; command="$2"; bad="$3"; wanted "$key" || return; t0=$(now_ms); output=$(run_limited "$command"); rc=$?; t1=$(now_ms); count=$(printf '%s\n' "$output" | awk 'NF{n++}END{print n+0}'); if [ $rc -ne 0 ]; then state=unavailable; elif [ -n "$bad" ] && printf '%s\n' "$output" | grep -Eiq "$bad"; then state=warning; else state=healthy; fi; encoded=$(printf '%s' "$output" | base64 -w0 2>/dev/null); printf 'check=%s|%s|%s|%s|%s|%s\n' "$key" "$state" "$count" "$encoded" "$rc" "$((t1-t0))"; }
emit_zero_check() { key="$1"; command="$2"; wanted "$key" || return; t0=$(now_ms); output=$(run_limited "$command"); rc=$?; t1=$(now_ms); value=$(printf '%s\n' "$output" | awk 'NF{v=$NF; if(v !~ /^[0-9]+$/){bad=1} else {seen=1; if(v>max)max=v}}END{if(bad || !seen)print "invalid"; else print max+0}'); if [ $rc -ne 0 ] || [ "$value" = invalid ]; then state=unavailable; value=0; elif [ "$value" -eq 0 ]; then state=healthy; else state=warning; fi; encoded=$(printf '%s' "$output" | base64 -w0 2>/dev/null); printf 'check=%s|%s|%s|%s|%s|%s\n' "$key" "$state" "$value" "$encoded" "$rc" "$((t1-t0))"; }
emit_check pcs 'pcs status' 'failed|stopped|offline|unclean'
emit_check vip 'ping -c 2 -W 2 "$PROVIDER_VIP"' '100% packet loss'
emit_check rabbitmq 'rabbitmqctl cluster_status' 'error|failed'
emit_check mysql 'mysql_query -NBe "show status like '\''wsrep_cluster_weight'\''"' '^$'
emit_zero_check mysql_host_blocked_errors 'mysql_query -NBe "select COUNT_HOST_BLOCKED_ERRORS from performance_schema.host_cache;"'
emit_zero_check wsrep_local_cert_failures 'mysql_query -NBe "show global status like '\''wsrep_local_cert_failures'\'';"'
emit_check endpoint 'openstack endpoint list -f table' ''
emit_check nova 'openstack compute service list -f table' ' down | disabled '
emit_check neutron 'openstack network agent list -f table' ' down | xxx '
emit_check cinder 'openstack volume service list -f table' ' down | disabled '
emit_check manila 'openstack share service list -f table' ' down | disabled '
emit_check octavia 'openstack loadbalancer list -f table' 'error'
emit_check masakari 'openstack segment list -f table || openstack service list -f table' 'error|failed'
emit_check swift 'openstack object store account show -f table || openstack service list -f table' 'error|failed'
emit_check heat 'openstack orchestration service list -f table || openstack service list -f table' 'down|disabled|failed'
emit_check vm 'openstack server list --all-projects -f table' ' error '
emit_check network 'openstack network agent list -f table' ' down '
emit_check volume 'openstack volume list --all-projects -f table' ' error '
emit_check snapshot 'openstack volume snapshot list --all-projects -f table' 'creating|error'
emit_check share 'openstack share list --all-projects -f table' 'creating|error'
emit_check lb 'openstack loadbalancer list -f table' 'error'
emit_check amphora 'openstack loadbalancer amphora list -f table' 'error'
emit_check masakari_notification 'openstack notification list -f table' 'error|failed'
emit_check swift_container 'openstack container list -f table' 'error|failed'
emit_check heat_stack 'openstack stack list --all-projects -f table' 'CREATE_FAILED|UPDATE_FAILED|DELETE_FAILED|ROLLBACK_FAILED|error'
exit 0
'''
    cluster_items = {}
    controller_seconds = None
    controller_script_timeout = INSPECTION_TIMEOUTS["controller_script"]
    options = provider_ssh_options(provider)
    options["known_hosts"] = provider_known_hosts(provider_id)
    # Prefer the active controller's inventory IP (resolved on the controller during
    # discovery); a bare hostname only works when the deploy server can resolve it,
    # and the VIP is the last resort because it can move between controllers.
    active_short = (provider["controller_hostname"] or "").split(".")[0]
    controller_target = provider["vip"]
    for node in nodes:
        if node.get("hostname", "").split(".")[0] == active_short and is_ip_address(node.get("address") or ""):
            controller_target = node["address"]
            break
    else:
        if provider["controller_hostname"]:
            try:
                await asyncio.to_thread(socket.gethostbyname, provider["controller_hostname"])
                controller_target = provider["controller_hostname"]
            except OSError:
                pass
    try:
        async with asyncssh.connect(controller_target, **options) as connection:
            # A full OpenStack selection can invoke many CLI commands. When an
            # API VIP is unavailable each command consumes its own connect
            # timeout, so allow the batch to finish and return per-item errors.
            sftp = None
            try:
                if database_credentials:
                    def option_value(value: str) -> str:
                        return value.replace("\\", "\\\\").replace('"', '\\"')
                    mysql_config = (
                        "[client]\n"
                        f"user=\"{option_value(database_credentials['username'])}\"\n"
                        f"password=\"{option_value(database_credentials['password'])}\"\n"
                        f"host=\"{option_value(database_credentials['host'])}\"\n"
                        f"port={database_credentials['port']}\n"
                    )
                    sftp = await connection.start_sftp_client()
                    async with sftp.open(mysql_defaults_path, "w"):
                        pass
                    await sftp.chmod(mysql_defaults_path, 0o600)
                    async with sftp.open(mysql_defaults_path, "w") as config_file:
                        await config_file.write(mysql_config)
                controller_started = datetime.now(timezone.utc)
                response = await run_as_root(connection, provider, controller_command, controller_script_timeout)
                controller_seconds = round((datetime.now(timezone.utc) - controller_started).total_seconds(), 1)
            finally:
                if sftp and mysql_defaults_path:
                    try:
                        await sftp.remove(mysql_defaults_path)
                    except (asyncssh.SFTPError, OSError):
                        pass
                    sftp.exit()
        for line in response.stdout.splitlines():
            match = re.fullmatch(r"check=([a-z_]+)\|(healthy|warning|unavailable)\|(\d+)\|([A-Za-z0-9+/=]*)(?:\|(\d+)\|(\d+))?", line)
            if match:
                key, item_status, count, encoded, rc, duration_ms = match.groups()
                rc = int(rc) if rc is not None else (0 if item_status != "unavailable" else 1)
                duration_ms = int(duration_ms or 0)
                try: output = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: output = "원본 출력 디코딩 실패"
                is_zero_check = key in {"mysql_host_blocked_errors", "wsrep_local_cert_failures"}
                if is_zero_check:
                    cluster_items[key] = {
                        "status": item_status, "result": count if item_status != "unavailable" else "-",
                        "note": f"명령 제한 시간 {INSPECTION_TIMEOUTS['openstack']}초 초과" if rc == 124 else "정상 기준: 0",
                        "details": [{"title": provider["controller_hostname"], "output": output or "출력 없음"}], "duration_seconds": round(duration_ms / 1000, 1),
                    }
                else:
                    cluster_items[key] = describe_cluster_item(key, item_status, int(count), output, rc, duration_ms, provider["controller_hostname"], controller_target)
    except HTTPException:
        raise
    except TimeoutError as exc:
        reason = f"활성 Controller 명령 실행 제한시간 초과 ({controller_script_timeout}초)"
        cluster_items = {
            key: {
                "status": "unavailable", "result": "-", "note": reason,
                "details": [{"title": controller_target, "output": f"SSH 접속 후 OpenStack 명령 실행이 {controller_script_timeout}초 안에 완료되지 않았습니다."}],
            }
            for key in controller_items
        }
    except PrivilegeError as exc:
        reason = "활성 Controller root 권한 획득 실패"
        cluster_items = {
            key: {
                "status": "unavailable", "result": "-", "note": reason,
                "details": [{"title": controller_target, "output": str(exc)}],
            }
            for key in controller_items
        }
    except (asyncssh.Error, OSError) as exc:
        reason = f"활성 Controller SSH 연결 실패: {node_failure_reason(exc)}"
        cluster_items = {
            key: {
                "status": "unavailable", "result": "-", "note": reason,
                "details": [{"title": controller_target, "output": str(exc) or reason}],
            }
            for key in controller_items
        }

    def aggregate_node_item(key: str, result_key: str | None = None, suffix: str = "", role: str | None = None) -> dict:
        targets = [node for node in node_results if role is None or node["role"] == role]
        available = [node for node in targets if node["reachable"] and node["metrics"].get(key) not in {None, "unavailable"}]
        if not available:
            details = [{"title": node["hostname"], "output": "SSH 접속 실패" if not node["reachable"] else "해당 구성 또는 조회값 없음"} for node in targets]
            return {"status": "unavailable", "result": "-", "note": "수집 가능한 노드 없음", "details": details}
        limit = METRIC_THRESHOLD_FIELDS.get(key)
        warning = [node for node in available if node["metrics"].get(key) == "warning" or (limit and isinstance(node["metrics"].get(key), (int, float)) and node["metrics"][key] >= thresholds[limit])]
        values = [node["metrics"].get(result_key or key) for node in available]
        display = f"최대 {max(value for value in values if isinstance(value, (int, float)))}{suffix}" if any(isinstance(value, (int, float)) for value in values) else f"{len(available)}대 확인"
        raw_key = {"cpu_used_percent": "cpu_raw", "memory_used_percent": "memory_raw", "disk_used_percent": "disk_raw"}.get(key, f"{key}_raw")
        details = [{"title": node["hostname"], "output": node["metrics"].get(raw_key) or str(node["metrics"].get(result_key or key, "확인 불가"))} for node in targets]
        timed_out = [node["hostname"] for node in available if node["metrics"].get(f"{key}_rc") == 124]
        note = f"{len(available)}/{len(targets)}대 수집"
        if timed_out:
            note += f" · 제한 시간 초과: {', '.join(timed_out)}"
        item = {"status": "warning" if warning else "healthy", "result": display, "note": note, "details": details}
        durations = [node["metrics"][f"{key}_ms"] for node in available if isinstance(node["metrics"].get(f"{key}_ms"), int)]
        if durations:
            item["duration_seconds"] = round(max(durations) / 1000, 1)
        return item

    def aggregate_bonding_item() -> dict:
        """Bonding applies to every role, but only nodes that actually have a bond are judged."""
        targets = node_results
        reachable = [node for node in targets if node["reachable"]]
        configured = [node for node in reachable if node["metrics"].get("bonding") in {"healthy", "warning"}]
        unconfigured = [node for node in reachable if node["metrics"].get("bonding") == "not_configured"]
        details = []
        for node in targets:
            if not node["reachable"]:
                details.append({"title": node["hostname"], "output": "SSH 접속 실패"}); continue
            state = node["metrics"].get("bonding")
            if state == "not_configured":
                details.append({"title": f"{node['hostname']} ({node['role']}) · 미구성", "output": "/proc/net/bonding 없음 · 단일 NIC 또는 팀 구성이 아닌 노드로 판정에서 제외"}); continue
            summary_lines = []
            for line in (node["metrics"].get("bonding_summary") or "").splitlines():
                parts = line.split("|")
                if len(parts) == 4:
                    name, mode, mii, slaves = parts
                    slave_text = ", ".join(slave.replace(":", " ") for slave in slaves.split()) or "slave 없음"
                    summary_lines.append(f"{name}: MII {mii} · {mode} · slaves {slave_text}")
            output = "\n".join(summary_lines) + ("\n\n" if summary_lines else "") + (node["metrics"].get("bonding_raw") or "")
            details.append({"title": f"{node['hostname']} ({node['role']}) · {'주의' if state == 'warning' else '정상'}", "output": output.strip() or "출력 없음"})
        if not reachable:
            return {"status": "unavailable", "result": "-", "note": "수집 가능한 노드 없음", "details": details}
        if not configured:
            return {"status": "healthy", "result": "미구성", "note": f"전체 {len(reachable)}대 Bonding 미구성 · 판정 대상 없음", "details": details, "applicability": "none"}
        warning = [node["hostname"] for node in configured if node["metrics"].get("bonding") == "warning"]
        note = f"구성 {len(configured)}대 · 미구성 {len(unconfigured)}대"
        if warning:
            note += f" · 링크 이상: {', '.join(warning)}"
        return {"status": "warning" if warning else "healthy", "result": f"{len(configured)}대 정상" if not warning else f"{len(warning)}/{len(configured)}대 이상", "note": note, "details": details}

    def aggregate_mount_item() -> dict:
        """Mount is a Controller-role check (Compute instance storage has its own item)."""
        item = aggregate_node_item("mount", role="controller")
        targets = [node for node in node_results if node["role"] == "controller" and node["reachable"] and node["metrics"].get("mount") not in {None, "unavailable"}]
        problems, facts = [], []
        for node in targets:
            summary = {}
            for line in (node["metrics"].get("mount_summary") or "").splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    summary[key] = value
            mounted = [entry for entry in summary.get("mounted", "").split(";") if entry]
            missing = [entry for entry in summary.get("fstab_missing", "").split(";") if entry]
            stale = [entry for entry in summary.get("stale", "").split(";") if entry]
            if missing:
                problems.append(f"{node['hostname']} fstab 미마운트 {', '.join(missing)}")
            if stale:
                problems.append(f"{node['hostname']} 응답 없는 마운트 {', '.join(stale)}")
            network = [entry.split()[0] for entry in mounted if len(entry.split()) > 2 and entry.split()[2] in {"nfs", "nfs4", "cifs", "glusterfs", "fuse.glusterfs", "ceph"}]
            facts.append(f"{node['hostname']} NFS/네트워크 {len(network)}")
            for detail in item["details"]:
                if detail["title"] == node["hostname"]:
                    glance = summary.get("glance", "")
                    header = [f"마운트 {len(mounted)}개 (네트워크 {len(network)}개)", f"Cinder NFS 공유 설정 {summary.get('nfs_shares', '0')}개", f"Glance 저장소 {glance or '경로 없음'}"]
                    if missing: header.append(f"fstab 미마운트: {', '.join(missing)}")
                    if stale: header.append(f"응답 없음: {', '.join(stale)}")
                    detail["output"] = " · ".join(header) + "\n\n" + (detail["output"] or "")
        if item["status"] in {"healthy", "warning"} and targets:
            item["note"] = (("; ".join(problems) + " · ") if problems else "") + f"Controller {len(targets)}대 · " + ", ".join(facts) + " · Compute는 인스턴스 저장소 항목에서 점검"
        return item

    def aggregate_log_item(service: str) -> dict:
        state_key = f"{service}_log"
        count_key = f"{service}_log_count"
        details = []
        def normalized_log_lines(output: str) -> list[str]:
            lines = []
            for line in output.splitlines():
                value = line.strip()
                if not value:
                    continue
                value = re.sub(r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\s*", "", value)
                value = re.sub(r"^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+", "", value)
                value = re.sub(r"\b(?:req-)?[0-9a-f]{8}-[0-9a-f-]{27,36}\b", "<id>", value, flags=re.I)
                lines.append(value)
            return lines
        previous_nodes = {
            node.get("hostname"): node for node in ((previous_check or {}).get("result", {}).get("nodes", []))
        }
        for node in node_results:
            state = node["metrics"].get(state_key) if node["reachable"] else "unavailable"
            current_output = node["metrics"].get(f"{service}_log_sample", "")
            previous_output = node["metrics"].get(f"{service}_previous_log_sample", "")
            if not previous_output:
                previous_output = previous_nodes.get(node["hostname"], {}).get("metrics", {}).get(f"{service}_log_sample", "")
            current_lines = Counter(normalized_log_lines(current_output))
            previous_lines = Counter(normalized_log_lines(previous_output))
            new_counter = current_lines - previous_lines
            new_lines, persistent_lines = [], []
            for original, normalized in zip(
                (line.strip() for line in current_output.splitlines() if line.strip()),
                normalized_log_lines(current_output),
            ):
                if new_counter[normalized] > 0:
                    new_lines.append(original)
                    new_counter[normalized] -= 1
                else:
                    persistent_lines.append(original)
            resolved_lines = list((previous_lines - current_lines).elements())
            # Long-running incidents repeat the same message every day; they must stay visible even when nothing is "new".
            top_messages = [{"message": message[:400], "count": number} for message, number in current_lines.most_common(5)]
            timed_out = node["metrics"].get(f"{service}_log_rc") == 124
            details.append({
                "hostname": node["hostname"], "role": node["role"], "status": state or "unavailable",
                "count": node["metrics"].get(count_key, 0), "excluded_count": node["metrics"].get(f"{service}_log_excluded", 0) or 0,
                "duration_seconds": round(node["metrics"][f"{service}_log_ms"] / 1000, 1) if isinstance(node["metrics"].get(f"{service}_log_ms"), int) else None,
                "note": "SSH 접속 실패" if not node["reachable"] else ((f"로그 검색 제한 시간 {INSPECTION_TIMEOUTS['log_scan']}초 초과" if timed_out else "로그 파일 없음") if state == "unavailable" else ""),
                "log_date": node["metrics"].get(f"{service}_log_date", ""),
                "previous_log_date": node["metrics"].get(f"{service}_previous_log_date", ""),
                "previous_count": sum(previous_lines.values()), "new_count": len(new_lines), "resolved_count": len(resolved_lines),
                "persistent_count": len(persistent_lines), "sample_count": sum(current_lines.values()), "top_messages": top_messages,
                "output": current_output, "new_output": "\n".join(new_lines), "persistent_output": "\n".join(persistent_lines),
            })
        available = [detail for detail in details if detail["status"] != "unavailable"]
        total = sum(detail["count"] for detail in available)
        status = "warning" if any(detail["status"] == "warning" for detail in available) else ("healthy" if available else "unavailable")
        affected = [detail["hostname"] for detail in details if detail["status"] == "warning"]
        new_total = sum(detail["new_count"] for detail in available)
        resolved_total = sum(detail["resolved_count"] for detail in available)
        log_date = next((detail["log_date"] for detail in available if detail["log_date"]), "전날")
        excluded_total = sum(detail["excluded_count"] for detail in available)
        persistent_total = sum(detail["persistent_count"] for detail in available)
        note = f"{log_date} 기준 · 신규 {new_total}건 · 해소 {resolved_total}건"
        if persistent_total: note += f" · 지속 {persistent_total}건(표본)"
        if excluded_total: note += f" · 제외 패턴 {excluded_total}건"
        if affected: note += f" · 오류 노드: {', '.join(affected)}"
        timed_out = [detail["hostname"] for detail in details if "제한 시간" in detail["note"]]
        if timed_out: note += f" · 제한 시간 초과: {', '.join(timed_out)}"
        raw_details = []
        for detail in details:
            comparison = detail["new_output"] or "전전날과 다른 신규 오류 없음"
            raw_details.append({"title": f"{detail['hostname']} ({detail['role']}) · 전전날 대비 신규/변경 로그", "output": comparison})
            if detail["persistent_output"]:
                summary_lines = [f"{entry['count']}회 · {entry['message']}" for entry in detail["top_messages"]]
                raw_details.append({"title": f"{detail['hostname']} ({detail['role']}) · 지속 오류(전전날에도 발생) 표본 {detail['persistent_count']}줄", "output": "\n".join(summary_lines) + "\n\n" + detail["persistent_output"]})
            raw_details.append({"title": f"{detail['hostname']} ({detail['role']}) · {detail['log_date'] or '전날'} 전체 오류", "output": detail["output"] or detail["note"] or "일치하는 오류 로그 없음"})
        item = {"status": status, "result": f"전체 {total}건 / 신규 {new_total}건", "note": note, "log_date": log_date, "new_count": new_total, "resolved_count": resolved_total, "persistent_count": persistent_total, "excluded_count": excluded_total, "nodes": details, "details": raw_details}
        durations = [detail["duration_seconds"] for detail in details if detail.get("duration_seconds") is not None]
        if durations:
            item["duration_seconds"] = max(durations)
        return item

    update_progress("aggregating", "노드별 결과를 집계하고 예외 규칙을 적용하고 있습니다.", selected_items, 88)
    items = {
        "cpu": aggregate_node_item("cpu_used_percent", suffix="%"), "memory": aggregate_node_item("memory_used_percent", suffix="%"),
        "disk": aggregate_node_item("disk_used_percent", suffix="%"), "chrony": aggregate_node_item("chrony"),
        "bonding": aggregate_bonding_item(), "mount": aggregate_mount_item(),
        "nova_compute": aggregate_node_item("nova_compute", role="compute"), **cluster_items,
        "virtualization": aggregate_node_item("virtualization"), "failed_units": aggregate_node_item("failed_units"),
        "kernel_errors": aggregate_node_item("kernel_errors"), "nic_state": aggregate_node_item("nic_state"),
        "ovs_state": aggregate_node_item("ovs_state"), "kvm_acceleration": aggregate_node_item("kvm_acceleration", role="compute"),
        "libvirt_state": aggregate_node_item("libvirt_state", role="compute"), "instance_storage": aggregate_node_item("instance_storage", role="compute"),
        "smart_health": aggregate_node_item("smart_health"), "raid_health": aggregate_node_item("raid_health"), **custom_items,
    }
    for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "masakari", "swift", "heat", "system"):
        items[f"{service}_log"] = aggregate_log_item(service)
    items = {key: value for key, value in items.items() if key in selected_items}
    exception_rules = list_check_exceptions(provider_id)
    def exception_for(key: str, hostname: str = "") -> dict | None:
        return next((rule for rule in exception_rules if rule["item_key"] == key and (not rule["node_hostname"] or rule["node_hostname"] == hostname)), None)
    for key, item in items.items():
        rule = exception_for(key)
        if item["status"] == "warning" and rule:
            item["status"] = "excepted"
            item["exception_reason"] = rule["reason"]
            item["note"] = f"예외 처리 · {rule['reason']}"
    warnings = []
    warnings.extend(f"{key}: 확인 필요" for key, item in items.items() if item["status"] == "warning")
    overall_status = "warning" if warnings or any(not node["reachable"] for node in node_results) else "healthy"
    metric_keys = {
        "cpu":"cpu_used_percent", "memory":"memory_used_percent", "disk":"disk_used_percent",
        "chrony":"chrony", "bonding":"bonding", "mount":"mount", "nova_compute":"nova_compute",
        "virtualization":"virtualization", "failed_units":"failed_units", "kernel_errors":"kernel_errors",
        "nic_state":"nic_state", "ovs_state":"ovs_state", "kvm_acceleration":"kvm_acceleration",
        "libvirt_state":"libvirt_state", "instance_storage":"instance_storage",
        "smart_health":"smart_health", "raid_health":"raid_health",
    }
    compute_only = {"nova_compute", "kvm_acceleration", "libvirt_state", "instance_storage"}
    controller_only = {"mount"}
    node_summary = []
    for node in node_results:
        problem_items, review_items, excepted_items = [], [], []
        for key, item in items.items():
            if key in compute_only and node["role"] != "compute" or key in controller_only and node["role"] != "controller":
                continue
            state = None
            if key.endswith("_log") and item.get("nodes"):
                detail = next((entry for entry in item["nodes"] if entry["hostname"] == node["hostname"]), None)
                state = detail.get("status") if detail else None
            elif key.startswith("custom:") and item.get("nodes"):
                detail = next((entry for entry in item["nodes"] if entry["hostname"] == node["hostname"]), None)
                state = detail.get("status") if detail else "not_applicable"
            elif key in metric_keys:
                value = node.get("metrics", {}).get(metric_keys[key])
                if key in {"cpu", "memory", "disk"} and isinstance(value, (int, float)):
                    state = "warning" if value >= thresholds[f"{key}_warning"] else "healthy"
                elif value == "not_configured":
                    state = "not_applicable"
                else:
                    state = value
            elif node["hostname"] == provider["controller_hostname"]:
                state = item.get("status")
            rule = exception_for(key, node["hostname"])
            if state == "warning":
                (excepted_items if rule else problem_items).append(key)
            elif state in {"unavailable", None} and key in metric_keys and not rule:
                review_items.append(key)
        if not node["reachable"]:
            problem_items.insert(0, "ssh")
        status = "problem" if problem_items else ("review" if review_items else "healthy")
        node_summary.append({
            "hostname": node["hostname"], "role": node["role"], "address": node.get("address", ""), "status": status,
            "problem_items": problem_items, "review_items": review_items, "excepted_items": excepted_items,
        })
    first_metrics = next((node["metrics"] for node in node_results if node["reachable"]), {})
    finished = datetime.now(timezone.utc)
    slowest = sorted(((key, item["duration_seconds"]) for key, item in items.items() if isinstance(item.get("duration_seconds"), (int, float))), key=lambda pair: pair[1], reverse=True)[:5]
    timing = {
        "nodes_seconds": nodes_seconds, "controller_seconds": controller_seconds,
        "node_seconds": {node["hostname"]: node.get("duration_seconds") for node in node_results},
        "slowest_items": [{"key": key, "seconds": seconds} for key, seconds in slowest],
        "timeouts": dict(INSPECTION_TIMEOUTS), "node_concurrency": RUNTIME["node_concurrency"], "thresholds": thresholds,
    }
    result = {"nodes": node_results, "node_summary": node_summary, "items": items, "selected_items": sorted(selected_items), "metrics": first_metrics, "warnings": warnings,
              "started_at": started.isoformat(), "finished_at": finished.isoformat(), "duration_seconds": round((finished - started).total_seconds(), 1), "trigger": trigger, "timing": timing,
              "maintenance_nodes": maintenance_nodes}
    check_id = save_check(provider_id, overall_status, result)
    sync_check_alerts(provider_id, check_id, items)
    update_progress("completed", "일일점검이 완료되었습니다.", [], 100, False)
    return {"check_id": check_id, "provider_id": provider_id, "status": overall_status, **result}


@app.get("/api/providers/{provider_id}/overview")
async def provider_overview(provider_id: str):
    """Everything the dashboard shows for one provider, with each inspection item taken from the most recent check that included it."""
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    history = list_checks(provider_id, 30)
    latest = history[0] if history else None
    custom_keys = {item["key"] for item in list_custom_checks(provider_id) if item["enabled"]}
    wanted_keys = CHECK_KEYS | custom_keys
    items_latest: dict[str, dict] = {}
    node_snapshot = None
    loaded = 0
    # Walk newest → oldest; load a full result only while it can still contribute something (a partial run
    # such as "cinder_log only" must not blank out the rest of the dashboard).
    for entry in history:
        missing = [key for key in entry["summary"].get("item_status", {}) if key in wanted_keys and key not in items_latest]
        needs_nodes = node_snapshot is None and entry["summary"].get("nodes", {}).get("total", 0) > 0
        if not missing and not needs_nodes:
            continue
        if loaded >= 10:
            break
        full = get_check(provider_id, entry["id"])
        loaded += 1
        if not full:
            continue
        result = full["result"]
        for key in missing:
            item = (result.get("items") or {}).get(key)
            if not isinstance(item, dict):
                continue
            items_latest[key] = {
                "status": item.get("status", "unavailable"), "result": item.get("result", "-"), "note": item.get("note", ""),
                "problems": item.get("problems") or [], "new_count": item.get("new_count"), "persistent_count": item.get("persistent_count"),
                "duration_seconds": item.get("duration_seconds"), "checked_at": full["checked_at"], "check_id": full["id"],
            }
        if needs_nodes and any(node.get("metrics") for node in result.get("nodes") or []):
            node_snapshot = {
                "checked_at": full["checked_at"], "check_id": full["id"],
                "nodes": [{"hostname": node.get("hostname"), "role": node.get("role"), "address": node.get("address", ""), "reachable": node.get("reachable", False),
                           "status": node.get("status"), "warnings": node.get("warnings") or [], "duration_seconds": node.get("duration_seconds"),
                           "metrics": {key: node.get("metrics", {}).get(key) for key in ("hostname", "uptime_seconds", "cpu_cores", "cpu_used_percent", "memory_total_kb", "memory_used_kb", "memory_used_percent", "disk_total_kb", "disk_used_kb", "disk_used_percent")}}
                          for node in result.get("nodes") or []],
                "node_summary": result.get("node_summary") or [],
            }
    alerts = [alert for alert in list_alerts(provider_id=provider_id, limit=300) if is_active_alert(alert)]
    alerts.sort(key=lambda alert: alert.get("last_detected_at") or "", reverse=True)
    critical = sum(1 for alert in alerts if alert.get("severity") == "critical")
    inventory = {"total": len(nodes), "controller": sum(1 for node in nodes if node["role"] == "controller"), "compute": sum(1 for node in nodes if node["role"] == "compute")}
    issue_items = sorted(
        ({"key": key, **value} for key, value in items_latest.items() if value["status"] in {"warning", "unavailable"}),
        key=lambda value: (value["status"] != "warning", value["key"]),
    )
    return {
        "provider": {"id": provider["id"], "name": provider["name"], "vip": provider["vip"], "controller_hostname": provider["controller_hostname"],
                     "username": provider["username"], "sudo_mode": provider.get("sudo_mode"), "created_at": provider.get("created_at"), "inventory": inventory},
        "latest": latest, "history": history[:14], "items": items_latest, "issue_items": issue_items, "node_snapshot": node_snapshot,
        "alerts": {"active": len(alerts), "critical": critical, "warning": len(alerts) - critical, "recent": alerts[:6]},
        "schedule": describe_check_schedule(get_check_schedule(provider_id)),
        "work_histories": list_work_histories(provider_id=provider_id, limit=5)[:5],
        "running": bool(CHECK_PROGRESS.get(provider_id, {}).get("running")),
    }


def local_date(value: str | None, tz) -> str | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(tz).date().isoformat()
    except ValueError:
        return None


@app.get("/api/overview")
async def fleet_overview():
    """Every provider at a glance plus today's to-do list: scheduled runs, unacknowledged critical alerts, planned work."""
    tz = schedule_timezone()
    now = datetime.now(tz)
    today = now.date().isoformat()
    providers = []
    open_critical: list[dict] = []
    for provider in list_providers():
        provider_id = provider["id"]
        checks = list_checks(provider_id, 2)
        latest = checks[0] if checks else None
        nodes = list_provider_nodes(provider_id)
        alerts = [alert for alert in list_alerts(provider_id=provider_id, limit=500) if is_active_alert(alert)]
        critical = [alert for alert in alerts if alert.get("severity") == "critical"]
        open_critical.extend(alert for alert in critical if alert.get("status") == "open")
        schedule = describe_check_schedule(get_check_schedule(provider_id))
        summary = (latest or {}).get("summary") or {}
        providers.append({
            "id": provider_id, "name": provider["name"], "vip": provider["vip"], "controller_hostname": provider.get("controller_hostname"), "username": provider["username"],
            "nodes": {"total": len(nodes), "controller": sum(1 for node in nodes if node["role"] == "controller"), "compute": sum(1 for node in nodes if node["role"] == "compute")},
            "latest": latest, "previous": checks[1] if len(checks) > 1 else None,
            "checked_today": local_date(latest["checked_at"], tz) == today if latest else False,
            "alerts": {"active": len(alerts), "critical": len(critical), "warning": len(alerts) - len(critical), "open": sum(1 for alert in alerts if alert.get("status") == "open")},
            "schedule": {"enabled": schedule.get("enabled"), "run_time": schedule.get("run_time"), "next_run_at": schedule.get("next_run_at"), "last_status": schedule.get("last_status"), "last_run_at": schedule.get("last_run_at"), "last_error": schedule.get("last_error"),
                         "today": ("done" if schedule.get("last_status") in {"healthy", "warning"} else "failed") if schedule.get("enabled") and local_date(schedule.get("last_run_at"), tz) == today and schedule.get("last_status") != "running"
                                  else ("running" if schedule.get("last_status") == "running" and local_date(schedule.get("last_run_at"), tz) == today else ("pending" if schedule.get("enabled") else "off"))},
            "running": bool(CHECK_PROGRESS.get(provider_id, {}).get("running")),
            "warning_items": summary.get("items", {}).get("warning", 0) if latest else None,
            "unavailable_items": summary.get("items", {}).get("unavailable", 0) if latest else None,
        })
    open_critical.sort(key=lambda alert: alert.get("last_detected_at") or "", reverse=True)
    works = [work for work in list_work_histories(limit=300) if work.get("status") in {"planned", "in_progress"}]
    works_today = [work for work in works if work.get("status") == "in_progress" or local_date(work.get("started_at"), tz) == today][:8]
    return {
        "server_time": now.isoformat(), "timezone": str(tz), "providers": providers,
        "totals": {"providers": len(providers), "nodes": sum(item["nodes"]["total"] for item in providers), "active_alerts": sum(item["alerts"]["active"] for item in providers),
                   "critical_alerts": sum(item["alerts"]["critical"] for item in providers), "checked_today": sum(1 for item in providers if item["checked_today"]),
                   "running": sum(1 for item in providers if item["running"]), "healthy": sum(1 for item in providers if item["latest"] and item["latest"]["status"] == "healthy"),
                   "warning": sum(1 for item in providers if item["latest"] and item["latest"]["status"] != "healthy"), "unchecked": sum(1 for item in providers if not item["latest"])},
        "today": {"schedules": [{"provider_id": item["id"], "provider_name": item["name"], **item["schedule"]} for item in providers if item["schedule"]["enabled"]],
                  "open_critical_alerts": open_critical[:8], "open_critical_total": len(open_critical), "works": works_today, "works_total": len(works)},
    }


@app.get("/api/providers/{provider_id}/checks/progress")
async def get_provider_check_progress(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return CHECK_PROGRESS.get(provider_id, {
        "running": False, "stage": "idle", "message": "실행 중인 점검이 없습니다.", "current_items": [], "percent": 0,
    })


@app.get("/api/providers/{provider_id}/checks")
async def list_provider_checks(provider_id: str, limit: int = Query(default=30, ge=1, le=200)):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    checks = list_checks(provider_id, limit)
    return {"provider_id": provider_id, "checks": checks, "count": len(checks)}


@app.get("/api/providers/{provider_id}/checks/{check_id}")
async def get_provider_check(provider_id: str, check_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    check = get_check(provider_id, check_id)
    if not check:
        raise HTTPException(404, "점검 결과를 찾을 수 없습니다.")
    return {"check": check}


def build_check_diff(current: dict, previous: dict | None) -> dict:
    """Item and node level changes between two stored check summaries."""
    if not previous:
        return {"current": {"id": current["id"], "checked_at": current["checked_at"], "status": current["status"]}, "previous": None, "items": [], "nodes": [], "counts": {}}
    issue = {"warning", "unavailable"}
    cur_items, prev_items = current["summary"]["item_status"], previous["summary"]["item_status"]
    items = []
    for key in sorted(set(cur_items) | set(prev_items)):
        before, after = prev_items.get(key), cur_items.get(key)
        if before == after:
            continue
        if before is None:
            change = "added"
        elif after is None:
            change = "removed"
        elif after in issue and before not in issue:
            change = "new_issue"
        elif before in issue and after not in issue:
            change = "resolved"
        elif before == "warning" and after == "unavailable" or before == "unavailable" and after == "warning":
            change = "changed"
        else:
            change = "changed"
        items.append({"key": key, "before": before, "after": after, "change": change})
    cur_nodes, prev_nodes = current["summary"]["node_status"], previous["summary"]["node_status"]
    cur_node_items, prev_node_items = current["summary"].get("node_items", {}), previous["summary"].get("node_items", {})
    nodes = []
    for hostname in sorted(set(cur_nodes) | set(prev_nodes)):
        before, after = prev_nodes.get(hostname), cur_nodes.get(hostname)
        before_set = set(prev_node_items.get(hostname, {}).get("problem", [])) | set(prev_node_items.get(hostname, {}).get("review", []))
        after_set = set(cur_node_items.get(hostname, {}).get("problem", [])) | set(cur_node_items.get(hostname, {}).get("review", []))
        if before == after and before_set == after_set:
            continue
        nodes.append({"hostname": hostname, "before": before, "after": after, "new_items": sorted(after_set - before_set), "resolved_items": sorted(before_set - after_set)})
    counts = {
        "new_issue": sum(1 for item in items if item["change"] == "new_issue"), "resolved": sum(1 for item in items if item["change"] == "resolved"),
        "changed": sum(1 for item in items if item["change"] == "changed"), "added": sum(1 for item in items if item["change"] == "added"),
        "removed": sum(1 for item in items if item["change"] == "removed"),
        "warning_delta": current["summary"]["items"]["warning"] - previous["summary"]["items"]["warning"],
        "unavailable_delta": current["summary"]["items"]["unavailable"] - previous["summary"]["items"]["unavailable"],
        "healthy_delta": (current["summary"]["items"]["healthy"] + current["summary"]["items"]["excepted"]) - (previous["summary"]["items"]["healthy"] + previous["summary"]["items"]["excepted"]),
        "problem_node_delta": current["summary"]["nodes"]["problem"] - previous["summary"]["nodes"]["problem"],
    }
    return {
        "current": {"id": current["id"], "checked_at": current["checked_at"], "status": current["status"]},
        "previous": {"id": previous["id"], "checked_at": previous["checked_at"], "status": previous["status"]},
        "items": items, "nodes": nodes, "counts": counts,
    }


@app.get("/api/providers/{provider_id}/checks/{check_id}/diff")
async def get_provider_check_diff(provider_id: str, check_id: str, against: str | None = Query(default=None)):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    current = check_summary(provider_id, check_id)
    if not current:
        raise HTTPException(404, "점검 결과를 찾을 수 없습니다.")
    previous = check_summary(provider_id, against) if against else previous_check_summary(provider_id, current["checked_at"])
    if against and not previous:
        raise HTTPException(404, "비교 대상 점검 결과를 찾을 수 없습니다.")
    return build_check_diff(current, previous)


def describe_check_schedule(schedule: dict) -> dict:
    """Attach the scheduler clock and the next firing time so the UI does not have to guess time zones."""
    tz = schedule_timezone()
    now = datetime.now(tz)
    next_run = None
    if schedule.get("enabled"):
        hours, minutes = (int(part) for part in schedule["run_time"].split(":"))
        next_run = now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
        last_run = schedule.get("last_run_at")
        ran_today = bool(last_run) and datetime.fromisoformat(last_run).astimezone(tz).date() == now.date()
        if next_run <= now or ran_today:
            next_run += timedelta(days=1)
    return {**schedule, "server_time": now.isoformat(), "timezone": str(tz), "next_run_at": next_run.isoformat() if next_run else None}


class InspectionReportRow(BaseModel):
    category: str = ""
    name: str = ""
    method: str = ""
    status: str = ""
    result: str = ""
    note: str = ""
    change: str = ""


class InspectionReportGroup(BaseModel):
    title: str = ""
    rows: list[InspectionReportRow] = Field(default_factory=list, max_length=500)


class InspectionReportRequest(BaseModel):
    provider: str = Field(default="-", max_length=200)
    checked_at: str = Field(default="", max_length=100)
    trigger: str | None = None
    duration_seconds: float | None = None
    groups: list[InspectionReportGroup] = Field(default_factory=list, max_length=50)


class IssueReportOutput(BaseModel):
    title: str = Field(default="", max_length=500)
    output: str = Field(default="", max_length=20000)


class IssueReportItem(BaseModel):
    group: str = Field(default="", max_length=200)
    name: str = Field(default="", max_length=300)
    method: str = Field(default="", max_length=1000)
    status: str = Field(default="", max_length=30)
    note: str = Field(default="", max_length=2000)
    result: str = Field(default="", max_length=2000)
    outputs: list[IssueReportOutput] = Field(default_factory=list, max_length=100)


class IssueReportRequest(BaseModel):
    provider: str = Field(default="-", max_length=200)
    checked_at: str = Field(default="", max_length=100)
    trigger: str | None = None
    duration_seconds: float | None = None
    items: list[IssueReportItem] = Field(default_factory=list, max_length=500)


# --- Inspection extensions: timing statistics ------------------------------------------------
@app.get("/api/providers/{provider_id}/check-timing")
async def get_provider_check_timing(provider_id: str, limit: int = Query(10, ge=1, le=30)):
    """Item and node durations over the last N checks, with a timeout suggestion derived from the observed maxima."""
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    entries = list_checks(provider_id, limit)
    item_durations: dict[str, list[float]] = {}
    node_durations: dict[str, list[float]] = {}
    phases = {"nodes": [], "controller": [], "total": []}
    sampled = 0
    for entry in entries:
        full = get_check(provider_id, entry["id"])
        if not full:
            continue
        result = full["result"]
        timing = result.get("timing") or {}
        if not timing and not result.get("items"):
            continue
        sampled += 1
        for key, item in (result.get("items") or {}).items():
            seconds = item.get("duration_seconds") if isinstance(item, dict) else None
            if isinstance(seconds, (int, float)):
                item_durations.setdefault(key, []).append(float(seconds))
        for hostname, seconds in (timing.get("node_seconds") or {}).items():
            if isinstance(seconds, (int, float)):
                node_durations.setdefault(hostname, []).append(float(seconds))
        for phase, source in (("nodes", timing.get("nodes_seconds")), ("controller", timing.get("controller_seconds")), ("total", result.get("duration_seconds"))):
            if isinstance(source, (int, float)):
                phases[phase].append(float(source))
    def stats(values: list[float]) -> dict:
        ordered = sorted(values)
        return {"avg": round(sum(ordered) / len(ordered), 1), "max": round(ordered[-1], 1), "p90": round(ordered[min(len(ordered) - 1, int(len(ordered) * 0.9))], 1), "samples": len(ordered)}
    items = sorted(({"key": key, **stats(values)} for key, values in item_durations.items()), key=lambda item: item["max"], reverse=True)
    nodes = sorted(({"hostname": hostname, **stats(values)} for hostname, values in node_durations.items()), key=lambda node: node["max"], reverse=True)
    log_keys = {f"{service}_log" for service in LOG_SERVICES}
    node_keys = {"cpu", "memory", "disk", "chrony", "bonding", "mount", "nova_compute", "virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration", "libvirt_state", "instance_storage", "smart_health", "raid_health"}
    def suggest(keys: set[str] | None, floor: int, cap: int, factor: float = 1.5) -> int | None:
        observed = [item["max"] for item in items if keys is None or item["key"] in keys]
        if not observed:
            return None
        return int(min(cap, max(floor, round(max(observed) * factor))))
    suggestions = {
        "command": suggest(node_keys - log_keys, 5, 600), "log_scan": suggest(log_keys, 10, 600),
        "openstack": suggest(set(item["key"] for item in items) - node_keys - log_keys, 10, 600),
        "node_script": int(min(3600, max(60, round(max(phases["nodes"]) * 1.5)))) if phases["nodes"] else None,
        "controller_script": int(min(3600, max(60, round(max(phases["controller"]) * 1.5)))) if phases["controller"] else None,
    }
    return {"sampled_checks": sampled, "items": items, "nodes": nodes, "phases": {phase: stats(values) if values else None for phase, values in phases.items()},
            "current_timeouts": dict(INSPECTION_TIMEOUTS), "suggested_timeouts": suggestions}


@app.post("/api/reports/issues.pdf")
async def create_issue_report_pdf(payload: IssueReportRequest):
    """상단 `PDF 저장`: 주의·확인 불가 항목만 담은 이상 항목 보고서. 이상 항목이 없어도 '이상 항목 없음' 보고서를 생성한다."""
    try:
        content = await asyncio.to_thread(build_issue_report_pdf, payload.model_dump())
    except Exception as exc:  # noqa: BLE001
        logger.exception("issue report pdf generation failed")
        raise HTTPException(500, f"PDF 생성에 실패했습니다: {exc}") from exc
    return Response(content=content, media_type="application/pdf", headers={"Content-Disposition": "attachment; filename=inspection-issues.pdf", "Cache-Control": "no-store"})


@app.post("/api/reports/inspection.pdf")
async def create_inspection_report_pdf(payload: InspectionReportRequest):
    if not any(group.rows for group in payload.groups):
        raise HTTPException(400, "PDF로 저장할 점검 내용이 없습니다.")
    try:
        content = await asyncio.to_thread(build_inspection_pdf, payload.model_dump())
    except Exception as exc:  # noqa: BLE001
        logger.exception("inspection pdf generation failed")
        raise HTTPException(500, f"PDF 생성에 실패했습니다: {exc}") from exc
    return Response(content=content, media_type="application/pdf", headers={"Content-Disposition": "attachment; filename=inspection-report.pdf", "Cache-Control": "no-store"})


@app.post("/api/reports/inspection.xlsx")
async def create_inspection_report_xlsx(payload: InspectionReportRequest):
    # Same payload as the PDF; the workbook mirrors the operator's original checklist layout so it can replace the manual form.
    if not any(group.rows for group in payload.groups):
        raise HTTPException(400, "Excel로 저장할 점검 내용이 없습니다.")
    data = payload.model_dump()
    try:
        content = await asyncio.to_thread(build_inspection_workbook, data)
    except Exception as exc:  # noqa: BLE001
        logger.exception("inspection xlsx generation failed")
        raise HTTPException(500, f"Excel 생성에 실패했습니다: {exc}") from exc
    filename = inspection_workbook_filename(data)
    return Response(content=content, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    headers={"Content-Disposition": f"attachment; filename=inspection-report.xlsx; filename*=UTF-8''{quote(filename)}", "Cache-Control": "no-store"})


@app.get("/api/providers/{provider_id}/check-schedule")
async def get_provider_check_schedule(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return describe_check_schedule(get_check_schedule(provider_id))


@app.put("/api/providers/{provider_id}/check-schedule")
async def update_provider_check_schedule(provider_id: str, request: CheckScheduleRequest):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    selected = None
    if request.selected_items is not None:
        available = CHECK_KEYS | {item["key"] for item in list_custom_checks(provider_id) if item["enabled"]}
        selected = [key for key in request.selected_items if key in available]
        if request.enabled and not selected:
            raise HTTPException(400, "예약 실행할 점검 항목을 하나 이상 선택하세요.")
    schedule = describe_check_schedule(save_check_schedule(provider_id, request.enabled, request.run_time, selected))
    audit("check.schedule.update", "provider", provider_id, provider_label(provider_id), f"{'사용' if request.enabled else '중지'} · 매일 {request.run_time} · 항목 {len(selected) if selected is not None else '전체'}")
    return schedule


def due_check_schedules(now: datetime) -> list[dict]:
    """Enabled schedules whose HH:MM matches `now` and that have not fired yet on `now`'s date."""
    due = []
    for schedule in list_enabled_check_schedules():
        if now.strftime("%H:%M") != schedule["run_time"]:
            continue
        last_run = schedule.get("last_run_at")
        if last_run and datetime.fromisoformat(last_run).astimezone(now.tzinfo).date() == now.date():
            continue
        if CHECK_PROGRESS.get(schedule["provider_id"], {}).get("running"):
            continue
        due.append(schedule)
    return due


async def run_scheduled_check(schedule: dict) -> None:
    provider_id = schedule["provider_id"]
    record_schedule_run(provider_id, "running", None, None)
    logger.info("Scheduled inspection started for provider %s (%s)", provider_id, schedule["run_time"])
    try:
        result = await run_provider_check(provider_id, CheckRequest(selected_items=schedule["selected_items"]), trigger="scheduled")
        record_schedule_run(provider_id, result["status"], result["check_id"], None)
        logger.info("Scheduled inspection finished for provider %s: %s (%s)", provider_id, result["status"], result["check_id"])
    except HTTPException as exc:
        record_schedule_run(provider_id, "failed", None, str(exc.detail))
        logger.warning("Scheduled inspection failed for provider %s: %s", provider_id, exc.detail)
    except Exception as exc:  # keep the scheduler alive no matter what a run does
        record_schedule_run(provider_id, "failed", None, type(exc).__name__)
        logger.exception("Scheduled inspection crashed for provider %s", provider_id)


async def run_retention_if_due(force: bool = False) -> None:
    """Apply the retention policy once a day (and at startup), never while an inspection is running."""
    last = LAST_PRUNE_AT.get("at")
    if not force and last and (datetime.now(timezone.utc) - last) < timedelta(hours=24):
        return
    if any(progress.get("running") for progress in CHECK_PROGRESS.values()):
        return
    LAST_PRUNE_AT["at"] = datetime.now(timezone.utc)
    result = await asyncio.to_thread(prune_check_results, **RETENTION_POLICY)
    audit_pruned = await asyncio.to_thread(prune_audit_logs, RUNTIME["audit_max_age_days"])
    if audit_pruned:
        logger.info("Audit log prune: deleted %d entries older than %d days", audit_pruned, RUNTIME["audit_max_age_days"])
    if result["deleted"] or result["compacted"]:
        logger.info("Inspection retention prune: deleted %s, compacted %s, freed %s bytes", result["deleted"], result["compacted"], result["freed_bytes"])


LAST_PRUNE_AT: dict[str, datetime] = {}


async def run_scheduled_checks():
    """Fire each enabled schedule once per local day at its configured HH:MM in INSPECTION_TIMEZONE."""
    logger.info("Inspection scheduler started (timezone %s, timeouts %s, retention %s)", schedule_timezone(), INSPECTION_TIMEOUTS, RETENTION_POLICY)
    while True:
        try:
            for schedule in due_check_schedules(datetime.now(schedule_timezone())):
                await run_scheduled_check(schedule)
            await run_retention_if_due()
        except Exception:
            logger.exception("Inspection scheduler iteration failed")
        await asyncio.sleep(20)


@app.on_event("startup")
async def start_check_scheduler():
    # Keep a strong reference: the event loop only holds weak references to tasks.
    task = asyncio.create_task(run_scheduled_checks())
    BACKGROUND_TASKS.add(task)
    task.add_done_callback(BACKGROUND_TASKS.discard)


# --- Infrastructure inventory ---------------------------------------------------------------------
# A read-only collection run (hardware, filesystems, NICs/bonds, services, VMs per node; hypervisors,
# instances, volumes, networks, projects, flavors and the storage backend from the active controller)
# stored as one JSON payload per run in provider_inventory. It reuses the inspection's SSH path.
from inventory_collector import apply_node_allocation_ratios, controller_script as inventory_controller_script, node_script as inventory_node_script, parse_controller_output, parse_node_output  # noqa: E402
from provider_store import get_inventory, latest_inventory, list_inventories, save_inventory  # noqa: E402

INVENTORY_PROGRESS: dict[str, dict] = {}
INVENTORY_TIMEOUTS = {
    "command": env_int("INVENTORY_COMMAND_TIMEOUT", 30, 5, 600),           # one command on a node / controller
    "node_script": env_int("INVENTORY_NODE_TIMEOUT", 180, 60, 3600),       # whole per-node script
    "controller_script": env_int("INVENTORY_CONTROLLER_TIMEOUT", 900, 60, 3600),  # whole controller script (many openstack calls)
}


def controller_connect_target(provider: dict, nodes: list[dict]) -> str:
    """Same preference as the inspection: active controller's inventory IP → resolvable hostname → VIP."""
    active_short = (provider.get("controller_hostname") or "").split(".")[0]
    for node in nodes:
        if node.get("hostname", "").split(".")[0] == active_short and is_ip_address(node.get("address") or ""):
            return node["address"]
    if provider.get("controller_hostname"):
        try:
            socket.gethostbyname(provider["controller_hostname"])
            return provider["controller_hostname"]
        except OSError:
            pass
    return provider["vip"]


def inventory_progress_update(provider_id: str, stage: str, message: str, percent: int, running: bool = True, started: datetime | None = None) -> None:
    INVENTORY_PROGRESS[provider_id] = {"running": running, "stage": stage, "message": message, "percent": percent,
                                       "started_at": (started or datetime.now(timezone.utc)).isoformat(), "updated_at": datetime.now(timezone.utc).isoformat()}


async def execute_inventory_collection(provider_id: str) -> dict:
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    if not nodes:
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
    started = datetime.now(timezone.utc)
    inventory_progress_update(provider_id, "nodes", f"전체 노드 {len(nodes)}대의 하드웨어·네트워크·서비스 정보를 수집하고 있습니다.", 10, started=started)
    node_command = inventory_node_script(INVENTORY_TIMEOUTS["command"])
    semaphore = asyncio.Semaphore(RUNTIME["node_concurrency"])

    async def collect_node(node: dict) -> dict:
        options = provider_ssh_options(provider)
        options["known_hosts"] = provider_known_hosts(provider_id)
        node_started = datetime.now(timezone.utc)
        base = {"hostname": node["hostname"], "role": node["role"], "address": node.get("address", ""), "source": node.get("source", "")}
        try:
            address = await resolve_node_address(node)
            async with semaphore:
                async with asyncssh.connect(address, **options) as connection:
                    response = await run_as_root(connection, provider, node_command, INVENTORY_TIMEOUTS["node_script"])
            parsed = parse_node_output(response.stdout)
            return {**base, "address": address, "reachable": True, "error": "", "duration_seconds": round((datetime.now(timezone.utc) - node_started).total_seconds(), 1), **parsed}
        except (asyncssh.Error, OSError, RuntimeError) as exc:
            reason = f"수집 명령이 {INVENTORY_TIMEOUTS['node_script']}초 안에 완료되지 않음" if isinstance(exc, TimeoutError) else node_failure_reason(exc)
            return {**base, "reachable": False, "error": reason, "duration_seconds": round((datetime.now(timezone.utc) - node_started).total_seconds(), 1)}

    node_results = await asyncio.gather(*(collect_node(node) for node in nodes))
    inventory_progress_update(provider_id, "openstack", "활성 Controller에서 하이퍼바이저·인스턴스·볼륨·네트워크·스토리지 정보를 수집하고 있습니다.", 60, started=started)
    controller_target = controller_connect_target(provider, nodes)
    controller = {"hostname": provider.get("controller_hostname"), "target": controller_target, "error": ""}
    controller_sections = {"openstack": {"available": False, "errors": {"connection": ""}, "hypervisors": [], "servers": [], "volumes": [], "networks": [], "projects": [], "flavors": []},
                           "capacity": {"hypervisors": [], "totals": {}, "projects": [], "instances": {"total": 0, "by_status": {}},
                                        "zones": [], "quota_available": False, "headroom": {"flavors": [], "results": []}},
                           "storage": {"backend": "none", "ceph": None, "nfs": {"mounts": [], "glance_on_nfs": False, "cinder_on_nfs": False, "cinder_mount_dirs": []}},
                           "api_access": {"ok": False, "message": "", "placement": False, "quota_projects": 0}}
    options = provider_ssh_options(provider)
    options["known_hosts"] = provider_known_hosts(provider_id)
    try:
        async with asyncssh.connect(controller_target, **options) as connection:
            response = await run_as_root(connection, provider, inventory_controller_script(INVENTORY_TIMEOUTS["command"]), INVENTORY_TIMEOUTS["controller_script"])
        controller_sections = parse_controller_output(response.stdout)
        # Placement covers most clouds, but a hypervisor it did not report can still be sized from
        # the allocation ratios in that node's own nova.conf, collected by the per-node script.
        apply_node_allocation_ratios(controller_sections["capacity"], node_results)
    except (asyncssh.Error, OSError, RuntimeError) as exc:
        controller["error"] = f"수집 명령이 {INVENTORY_TIMEOUTS['controller_script']}초 안에 완료되지 않음" if isinstance(exc, TimeoutError) else f"활성 Controller SSH 연결 실패: {node_failure_reason(exc)}"
        controller_sections["openstack"]["errors"]["connection"] = controller["error"]
    inventory_progress_update(provider_id, "saving", "수집 결과를 저장하고 있습니다.", 90, started=started)
    duration = round((datetime.now(timezone.utc) - started).total_seconds(), 1)
    reachable = sum(1 for node in node_results if node["reachable"])
    openstack_ok = controller_sections["openstack"].get("available", False)
    status = "healthy" if reachable == len(node_results) and openstack_ok else ("unavailable" if reachable == 0 else "warning")
    payload = {
        "collected_at": started.isoformat(), "duration_seconds": duration, "status": status, "trigger": "manual",
        "provider": {"id": provider_id, "name": provider["name"], "vip": provider["vip"], "controller_hostname": provider.get("controller_hostname")},
        "controller": controller, "nodes": node_results, **controller_sections,
        "summary": {"nodes": len(node_results), "reachable": reachable, "openstack_available": openstack_ok,
                    "hypervisors": len(controller_sections["capacity"].get("hypervisors", [])), "instances": controller_sections["capacity"].get("instances", {}).get("total", 0),
                    "volumes": len(controller_sections["openstack"].get("volumes", [])), "networks": len(controller_sections["openstack"].get("networks", [])),
                    "storage_backend": controller_sections["storage"].get("backend", "none")},
    }
    inventory_id = save_inventory(provider_id, status, duration, payload)
    inventory_progress_update(provider_id, "done", f"인벤토리 수집 완료 · 노드 {reachable}/{len(node_results)}대 · {duration}초", 100, running=False, started=started)
    audit("inventory.collect", "provider", provider_id, provider["name"],
          f"결과 {status} · 노드 {reachable}/{len(node_results)}대 · 하이퍼바이저 {payload['summary']['hypervisors']} · 인스턴스 {payload['summary']['instances']} · 스토리지 {payload['summary']['storage_backend']} · {duration}초",
          outcome="success" if status != "unavailable" else "failure")
    return {"inventory_id": inventory_id, "status": status, "duration_seconds": duration, "summary": payload["summary"], "collected_at": payload["collected_at"]}


@app.post("/api/providers/{provider_id}/inventory/collect")
async def collect_provider_inventory(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if INVENTORY_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "이미 이 공급자의 인벤토리 수집이 실행 중입니다. 완료 후 다시 실행하세요.")
    started = datetime.now(timezone.utc)
    try:
        return await execute_inventory_collection(provider_id)
    except HTTPException as exc:
        inventory_progress_update(provider_id, "failed", f"인벤토리 수집 실패: {exc.detail}", 0, running=False, started=started)
        audit("inventory.collect", "provider", provider_id, provider_label(provider_id), str(exc.detail), outcome="failure")
        raise
    except Exception as exc:  # noqa: BLE001
        inventory_progress_update(provider_id, "failed", f"인벤토리 수집 실패: {type(exc).__name__}", 0, running=False, started=started)
        audit("inventory.collect", "provider", provider_id, provider_label(provider_id), type(exc).__name__, outcome="failure")
        logger.exception("inventory collection crashed for provider %s", provider_id)
        raise HTTPException(500, f"인벤토리 수집 중 오류가 발생했습니다: {type(exc).__name__}") from exc


@app.get("/api/providers/{provider_id}/inventory/progress")
async def get_provider_inventory_progress(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return INVENTORY_PROGRESS.get(provider_id, {"running": False, "stage": "idle", "message": "실행 중인 인벤토리 수집이 없습니다.", "percent": 0})


@app.get("/api/providers/{provider_id}/inventory")
async def get_provider_inventory(provider_id: str, history: int = 0, inventory_id: str = ""):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if history:
        return {"provider_id": provider_id, "history": list_inventories(provider_id, 10)}
    inventory = get_inventory(provider_id, inventory_id) if inventory_id else latest_inventory(provider_id)
    if inventory_id and not inventory:
        raise HTTPException(404, "인벤토리 기록을 찾을 수 없습니다.")
    return {"provider_id": provider_id, "inventory": inventory, "running": bool(INVENTORY_PROGRESS.get(provider_id, {}).get("running")), "timeouts": INVENTORY_TIMEOUTS}


@app.get("/api/providers/{provider_id}/infrastructure/metrics")
async def provider_infrastructure_metrics(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    controllers = []
    for node in list_provider_nodes(provider_id):
        if node["role"] != "controller":
            continue
        target = node["address"] if is_ip_address(node.get("address") or "") else node["hostname"]
        if target not in controllers:
            controllers.append(target)
    if provider["controller_hostname"] and not controllers:
        controllers.append(provider["controller_hostname"])
    if provider["vip"] not in controllers:
        controllers.append(provider["vip"])
    base_url = None
    async with httpx.AsyncClient(timeout=5, follow_redirects=False) as client:
        for hostname in controllers:
            candidate = f"http://{hostname}:9090"
            try:
                response = await client.get(f"{candidate}/-/ready")
                if response.status_code == 200:
                    base_url = candidate
                    break
            except httpx.HTTPError:
                continue
        if not base_url:
            raise HTTPException(503, "접근 가능한 Prometheus Controller를 찾을 수 없습니다.")
        queries = {
            "cpu": '100 - (avg by(instance,nodename) (rate(node_cpu_seconds_total{job="node_exporter",mode="idle"}[5m])) * 100)',
            "memory": '(1 - node_memory_MemAvailable_bytes{job="node_exporter"} / node_memory_MemTotal_bytes{job="node_exporter"}) * 100',
            "disk": '(1 - node_filesystem_avail_bytes{job="node_exporter",mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{job="node_exporter",mountpoint="/",fstype!~"tmpfs|overlay"}) * 100',
            "network": 'sum by(instance,nodename) (rate(node_network_receive_bytes_total{job="node_exporter",device!="lo"}[5m]) + rate(node_network_transmit_bytes_total{job="node_exporter",device!="lo"}[5m]))',
        }
        async def instant(name: str, query: str):
            response = await client.get(f"{base_url}/api/v1/query", params={"query": query})
            response.raise_for_status()
            result = response.json()
            if result.get("status") != "success": raise ValueError(result.get("error", "Prometheus query failed"))
            return name, result["data"]["result"]
        try:
            instant_results = dict(await asyncio.gather(*(instant(name, query) for name, query in queries.items())))
            end = datetime.now(timezone.utc)
            start = end - timedelta(hours=6)
            history_queries = {
                "cpu": f"avg({queries['cpu']})",
                "memory": f"avg({queries['memory']})",
                "disk": f"avg({queries['disk']})",
            }
            async def history(name: str, query: str):
                response = await client.get(f"{base_url}/api/v1/query_range", params={
                    "query": query, "start": start.timestamp(), "end": end.timestamp(), "step": 300,
                })
                response.raise_for_status()
                result = response.json()
                series = result.get("data", {}).get("result", [])
                return name, (series[0].get("values", []) if series else [])
            history_results = dict(await asyncio.gather(*(history(name, query) for name, query in history_queries.items())))
        except (httpx.HTTPError, ValueError, KeyError) as exc:
            raise HTTPException(502, f"Prometheus 메트릭 조회에 실패했습니다: {type(exc).__name__}") from exc
    nodes: dict[str, dict] = {}
    for metric_name, series in instant_results.items():
        for item in series:
            labels = item.get("metric", {})
            hostname = labels.get("nodename") or labels.get("instance", "").split(":", 1)[0]
            try: value = round(float(item["value"][1]), 2)
            except (KeyError, ValueError, TypeError, IndexError): continue
            nodes.setdefault(hostname, {"hostname": hostname, "instance": labels.get("instance", "")})[metric_name] = value
    up = instant_results.get("cpu", [])
    return {
        "status": "connected", "source": base_url, "collected_at": datetime.now(timezone.utc).isoformat(),
        "targets": len(up), "nodes": sorted(nodes.values(), key=lambda node: node["hostname"]),
        "history": {name: [[float(timestamp), round(float(value), 2)] for timestamp, value in values] for name, values in history_results.items()},
    }


MONITORING_RANGES = {"1h": (3600, 60), "6h": (6 * 3600, 300), "24h": (24 * 3600, 900), "7d": (7 * 24 * 3600, 3600)}
NODE_EXPORTER_QUERIES = {
    "cpu": '100 - (avg by(instance,nodename) (rate(node_cpu_seconds_total{job="node_exporter",mode="idle"}[5m])) * 100)',
    "memory": '(1 - node_memory_MemAvailable_bytes{job="node_exporter"} / node_memory_MemTotal_bytes{job="node_exporter"}) * 100',
    "disk": '(1 - node_filesystem_avail_bytes{job="node_exporter",mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{job="node_exporter",mountpoint="/",fstype!~"tmpfs|overlay"}) * 100',
    "network_rx": 'sum by(instance,nodename) (rate(node_network_receive_bytes_total{job="node_exporter",device!~"lo|veth.*|br.*|docker.*|tap.*|qbr.*|qvb.*|qvo.*"}[5m]))',
    "network_tx": 'sum by(instance,nodename) (rate(node_network_transmit_bytes_total{job="node_exporter",device!~"lo|veth.*|br.*|docker.*|tap.*|qbr.*|qvb.*|qvo.*"}[5m]))',
    "load1": 'node_load1{job="node_exporter"}',
    "cores": 'count by(instance,nodename) (node_cpu_seconds_total{job="node_exporter",mode="idle"})',
    "uptime": 'time() - node_boot_time_seconds{job="node_exporter"}',
    "memory_total": 'node_memory_MemTotal_bytes{job="node_exporter"}',
    "disk_total": 'node_filesystem_size_bytes{job="node_exporter",mountpoint="/",fstype!~"tmpfs|overlay"}',
}


async def discover_prometheus(client: httpx.AsyncClient, provider: dict, nodes: list[dict]) -> str | None:
    """First reachable Prometheus (port 9090) among controller inventory IPs, the registered controller name and the VIP."""
    candidates = []
    for node in nodes:
        if node["role"] != "controller":
            continue
        target = node["address"] if is_ip_address(node.get("address") or "") else node["hostname"]
        if target not in candidates:
            candidates.append(target)
    if provider["controller_hostname"] and not candidates:
        candidates.append(provider["controller_hostname"])
    if provider["vip"] not in candidates:
        candidates.append(provider["vip"])
    for hostname in candidates:
        candidate = f"http://{hostname}:9090"
        try:
            response = await client.get(f"{candidate}/-/ready")
            if response.status_code == 200:
                return candidate
        except httpx.HTTPError:
            continue
    return None


def inspection_resource_history(provider_id: str, limit: int = 20) -> dict:
    """Per-check CPU/memory/disk average and maximum from stored node metrics (the fallback when no Prometheus exists)."""
    series = {"cpu": [], "memory": [], "disk": []}
    checks = []
    for entry in list_checks(provider_id, limit):
        if entry["summary"].get("nodes", {}).get("total", 0) == 0:
            continue
        full = get_check(provider_id, entry["id"])
        if not full:
            continue
        nodes = [node for node in full["result"].get("nodes") or [] if node.get("reachable")]
        timestamp = datetime.fromisoformat(full["checked_at"]).timestamp()
        point = {"checked_at": full["checked_at"], "check_id": full["id"]}
        for metric, key in (("cpu", "cpu_used_percent"), ("memory", "memory_used_percent"), ("disk", "disk_used_percent")):
            values = [float(node["metrics"][key]) for node in nodes if isinstance(node.get("metrics", {}).get(key), (int, float))]
            if values:
                series[metric].append([timestamp, round(sum(values) / len(values), 1), round(max(values), 1)])
                point[metric] = {"avg": round(sum(values) / len(values), 1), "max": round(max(values), 1)}
        checks.append(point)
    for metric in series:
        series[metric].sort(key=lambda item: item[0])
    checks.sort(key=lambda item: item["checked_at"])
    return {"series": series, "checks": checks}


@app.get("/api/providers/{provider_id}/monitoring")
async def provider_monitoring(provider_id: str, range: str = Query(default="6h")):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if range not in MONITORING_RANGES:
        raise HTTPException(400, "지원하지 않는 조회 범위입니다. 1h, 6h, 24h, 7d 중에서 선택하세요.")
    seconds, step = MONITORING_RANGES[range]
    nodes = list_provider_nodes(provider_id)
    roles = {node["hostname"]: node["role"] for node in nodes}
    roles.update({node["hostname"].split(".")[0]: node["role"] for node in nodes})
    prometheus: dict = {"status": "unavailable", "source": None, "error": None}
    async with prometheus_client(provider_id) as client:
        base_url = await resolve_prometheus(client, provider, nodes)
        if base_url:
            async def instant(name: str, query: str):
                return name, await prom_instant(client, base_url, query)

            async def ranged(name: str, query: str, end: datetime):
                return name, prom_points(await prom_range(client, base_url, query, seconds, step, end))

            try:
                end = datetime.now(timezone.utc)
                instant_results = dict(await asyncio.gather(*(instant(name, query) for name, query in NODE_EXPORTER_QUERIES.items()), instant("up", "up")))
                range_queries = {
                    "cpu_avg": f"avg({NODE_EXPORTER_QUERIES['cpu']})", "cpu_max": f"max({NODE_EXPORTER_QUERIES['cpu']})",
                    "memory_avg": f"avg({NODE_EXPORTER_QUERIES['memory']})", "memory_max": f"max({NODE_EXPORTER_QUERIES['memory']})",
                    "disk_avg": f"avg({NODE_EXPORTER_QUERIES['disk']})", "disk_max": f"max({NODE_EXPORTER_QUERIES['disk']})",
                    "network_rx": f"sum({NODE_EXPORTER_QUERIES['network_rx']})", "network_tx": f"sum({NODE_EXPORTER_QUERIES['network_tx']})",
                }
                range_results = dict(await asyncio.gather(*(ranged(name, query, end) for name, query in range_queries.items())))
            except (httpx.HTTPError, ValueError, KeyError) as exc:
                prometheus = {"status": "error", "source": base_url, "error": f"Prometheus 조회 실패: {type(exc).__name__}"}
            else:
                node_metrics: dict[str, dict] = {}
                for metric_name, series in instant_results.items():
                    if metric_name == "up":
                        continue
                    for item in series:
                        labels = item.get("metric", {})
                        hostname = labels.get("nodename") or labels.get("instance", "").split(":", 1)[0]
                        try:
                            value = round(float(item["value"][1]), 2)
                        except (KeyError, ValueError, TypeError, IndexError):
                            continue
                        node_metrics.setdefault(hostname, {"hostname": hostname, "instance": labels.get("instance", ""), "role": roles.get(hostname) or roles.get(hostname.split(".")[0], "")})[metric_name] = value
                targets = []
                for item in instant_results.get("up", []):
                    labels = item.get("metric", {})
                    try:
                        healthy = float(item["value"][1]) >= 1
                    except (KeyError, ValueError, TypeError, IndexError):
                        healthy = False
                    targets.append({"job": labels.get("job", ""), "instance": labels.get("instance", ""), "nodename": labels.get("nodename", ""), "up": healthy})
                targets.sort(key=lambda target: (target["up"], target["job"], target["instance"]))
                prometheus = {
                    "status": "connected", "source": base_url, "collected_at": end.isoformat(), "range": range, "step": step,
                    "nodes": sorted(node_metrics.values(), key=lambda node: (node.get("role") != "controller", node["hostname"])),
                    "targets": targets, "targets_up": sum(1 for target in targets if target["up"]), "targets_total": len(targets),
                    "series": {
                        "cpu": {"avg": range_results["cpu_avg"], "max": range_results["cpu_max"]},
                        "memory": {"avg": range_results["memory_avg"], "max": range_results["memory_max"]},
                        "disk": {"avg": range_results["disk_avg"], "max": range_results["disk_max"]},
                        "network": {"rx": range_results["network_rx"], "tx": range_results["network_tx"]},
                    },
                }
    inspection = await asyncio.to_thread(inspection_resource_history, provider_id, 20 if prometheus["status"] != "connected" else 10)
    latest_nodes = None
    if prometheus["status"] != "connected":
        latest = latest_check(provider_id)
        if latest:
            latest_nodes = {"checked_at": latest["checked_at"], "nodes": [
                {"hostname": node.get("hostname"), "role": node.get("role"), "reachable": node.get("reachable", False),
                 "cpu": node.get("metrics", {}).get("cpu_used_percent"), "memory": node.get("metrics", {}).get("memory_used_percent"), "disk": node.get("metrics", {}).get("disk_used_percent"),
                 "cores": node.get("metrics", {}).get("cpu_cores"), "uptime": node.get("metrics", {}).get("uptime_seconds"),
                 "memory_total": (node.get("metrics", {}).get("memory_total_kb") or 0) * 1024, "disk_total": (node.get("metrics", {}).get("disk_total_kb") or 0) * 1024}
                for node in latest["result"].get("nodes") or []]}
    return {"provider": {"id": provider["id"], "name": provider["name"], "vip": provider["vip"]}, "range": range, "prometheus": prometheus,
            "inspection": inspection, "inspection_nodes": latest_nodes, "inventory": {"total": len(nodes), "controller": sum(1 for n in nodes if n["role"] == "controller"), "compute": sum(1 for n in nodes if n["role"] == "compute")}}


# --- Monitoring extensions ---------------------------------------------------------------------
# Collector settings per provider (Prometheus URL/auth/TLS, Grafana, Alertmanager), threshold rules that
# turn node_exporter values into alerts, node drill-down, OpenStack API/HAProxy status, Alertmanager
# firing alerts and a read-only PromQL proxy. Every Prometheus access goes through prometheus_client().
MONITORING_SETTING_DEFAULTS = {"prometheus_url": "", "auth_type": "none", "username": "", "secret_encrypted": "", "verify_tls": True, "grafana_url": "", "alertmanager_url": ""}
MONITORING_AUTH_TYPES = {"none", "basic", "bearer"}
DEFAULT_ALERT_RULES = {
    "enabled": True, "sustained_minutes": 5,
    "cpu": {"warning": 85, "critical": 95}, "memory": {"warning": 85, "critical": 95}, "disk": {"warning": 85, "critical": 95},
    "load_per_core": {"warning": 2.0, "critical": 4.0}, "node_down": True, "target_down": True,
}
MONITORING_EVALUATOR_INTERVAL = env_int("MONITORING_EVALUATOR_INTERVAL", 60, 15, 3600)
MONITORING_EVALUATOR_INITIAL_DELAY = env_int("MONITORING_EVALUATOR_INITIAL_DELAY", 90, 0, 3600)
OPENSTACK_API_PORTS = [("keystone", "Keystone", 5000), ("nova", "Nova", 8774), ("neutron", "Neutron", 9696), ("cinder", "Cinder", 8776), ("glance", "Glance", 9292),
                       ("placement", "Placement", 8778), ("heat", "Heat", 8004), ("octavia", "Octavia", 9876), ("manila", "Manila", 8786), ("swift", "Swift", 8080)]
MONITORING_LAST_EVALUATION: dict[str, dict] = {}


class MonitoringSettingsRequest(BaseModel):
    prometheus_url: str = Field("", max_length=300)
    auth_type: str = Field("none", max_length=10)
    username: str = Field("", max_length=128)
    secret: str | None = Field(None, max_length=1024)  # None keeps the stored secret, "" clears it
    verify_tls: bool = True
    grafana_url: str = Field("", max_length=300)
    alertmanager_url: str = Field("", max_length=300)


class AlertRulesRequest(BaseModel):
    value: dict


class ThresholdPairRequest(BaseModel):
    warning: float
    critical: float


def validate_http_url(value: str, label: str) -> str:
    value = (value or "").strip().rstrip("/")
    if not value:
        return ""
    if not re.match(r"^https?://[A-Za-z0-9.\-\[\]:_]+(?::\d{1,5})?(?:/[^\s]*)?$", value):
        raise HTTPException(400, f"{label} 주소는 http:// 또는 https://로 시작하는 URL이어야 합니다.")
    return value


def monitoring_settings(provider_id: str) -> dict:
    stored = provider_setting(provider_id, "monitoring")
    return {**MONITORING_SETTING_DEFAULTS, **{key: value for key, value in (stored or {}).items() if key in MONITORING_SETTING_DEFAULTS}}


def public_monitoring_settings(provider_id: str) -> dict:
    settings = monitoring_settings(provider_id)
    info = get_setting_info(provider_setting_key(provider_id, "monitoring"))
    return {**{key: value for key, value in settings.items() if key != "secret_encrypted"}, "secret_configured": bool(settings["secret_encrypted"]),
            "source": "stored" if info else "default", "updated_at": info["updated_at"] if info else None, "updated_by": info["updated_by"] if info else None}


def prometheus_client(provider_id: str, timeout: float = 8) -> httpx.AsyncClient:
    """One HTTP client per request carrying the provider's collector auth and TLS policy."""
    settings = monitoring_settings(provider_id)
    headers = {}
    auth = None
    if settings["auth_type"] == "basic" and settings["username"]:
        auth = (settings["username"], decrypt_secret(settings["secret_encrypted"]) if settings["secret_encrypted"] else "")
    elif settings["auth_type"] == "bearer" and settings["secret_encrypted"]:
        headers["Authorization"] = f"Bearer {decrypt_secret(settings['secret_encrypted'])}"
    return httpx.AsyncClient(timeout=timeout, follow_redirects=False, verify=bool(settings["verify_tls"]), headers=headers, auth=auth)


async def resolve_prometheus(client: httpx.AsyncClient, provider: dict, nodes: list[dict]) -> str | None:
    """Configured collector first (must answer /-/ready), then the 9090 discovery on controllers and the VIP."""
    configured = monitoring_settings(provider["id"])["prometheus_url"]
    if configured:
        try:
            response = await client.get(f"{configured}/-/ready")
            if response.status_code == 200:
                return configured
            logger.warning("Configured Prometheus %s for provider %s answered %s; falling back to discovery", configured, provider["id"], response.status_code)
        except httpx.HTTPError as exc:
            logger.warning("Configured Prometheus %s for provider %s unreachable (%s); falling back to discovery", configured, provider["id"], type(exc).__name__)
    return await discover_prometheus(client, provider, nodes)


async def prom_instant(client: httpx.AsyncClient, base_url: str, query: str) -> list[dict]:
    response = await client.get(f"{base_url}/api/v1/query", params={"query": query})
    response.raise_for_status()
    result = response.json()
    if result.get("status") != "success":
        raise ValueError(result.get("error", "Prometheus query failed"))
    return result["data"]["result"]


async def prom_range(client: httpx.AsyncClient, base_url: str, query: str, seconds: int, step: int, end: datetime | None = None) -> list[dict]:
    end = end or datetime.now(timezone.utc)
    response = await client.get(f"{base_url}/api/v1/query_range", params={"query": query, "start": (end - timedelta(seconds=seconds)).timestamp(), "end": end.timestamp(), "step": step})
    response.raise_for_status()
    result = response.json()
    if result.get("status") != "success":
        raise ValueError(result.get("error", "Prometheus query failed"))
    return result["data"]["result"]


def prom_points(series: list[dict]) -> list[list[float]]:
    return [[float(timestamp), round(float(value), 2)] for timestamp, value in (series[0].get("values", []) if series else []) if value not in ("NaN", "+Inf", "-Inf")]


def prom_value(item: dict) -> float | None:
    try:
        value = float(item["value"][1])
    except (KeyError, ValueError, TypeError, IndexError):
        return None
    return None if value != value else value  # NaN guard


def prom_hostname(labels: dict) -> str:
    return labels.get("nodename") or labels.get("instance", "").split(":", 1)[0]


def hostname_matches(candidate: str, hostname: str, address: str = "") -> bool:
    candidate = (candidate or "").lower()
    hostname = (hostname or "").lower()
    if not candidate:
        return False
    return candidate == hostname or candidate.split(".")[0] == hostname.split(".")[0] or (bool(address) and candidate == address)


@app.get("/api/providers/{provider_id}/monitoring/settings")
async def get_monitoring_settings(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return public_monitoring_settings(provider_id)


@app.put("/api/providers/{provider_id}/monitoring/settings")
async def update_monitoring_settings(provider_id: str, payload: MonitoringSettingsRequest, request: Request):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if payload.auth_type not in MONITORING_AUTH_TYPES:
        raise HTTPException(400, "인증 방식은 none, basic, bearer 중 하나여야 합니다.")
    current = monitoring_settings(provider_id)
    value = {
        "prometheus_url": validate_http_url(payload.prometheus_url, "Prometheus"), "auth_type": payload.auth_type, "username": payload.username.strip()[:128],
        "verify_tls": bool(payload.verify_tls), "grafana_url": validate_http_url(payload.grafana_url, "Grafana"), "alertmanager_url": validate_http_url(payload.alertmanager_url, "Alertmanager"),
        "secret_encrypted": current["secret_encrypted"],
    }
    if payload.secret is not None:
        value["secret_encrypted"] = encrypt_secret(payload.secret) if payload.secret else ""
    if payload.auth_type == "none":
        value["secret_encrypted"] = ""
        value["username"] = ""
    if payload.auth_type == "basic" and not value["username"]:
        raise HTTPException(400, "basic 인증에는 사용자명이 필요합니다.")
    if payload.auth_type != "none" and not value["secret_encrypted"]:
        raise HTTPException(400, "인증 비밀번호 또는 토큰을 입력하세요.")
    username = request.state.user["username"] if request.state.user else ""
    set_setting(provider_setting_key(provider_id, "monitoring"), value, username)
    audit("monitoring.settings.update", "provider", provider_id, provider_label(provider_id),
          f"Prometheus {value['prometheus_url'] or '자동 탐색'} · 인증 {value['auth_type']} · TLS 검증 {'사용' if value['verify_tls'] else '해제'} · Grafana {value['grafana_url'] or '-'} · Alertmanager {value['alertmanager_url'] or '-'}")
    return public_monitoring_settings(provider_id)


@app.post("/api/providers/{provider_id}/monitoring/test")
async def test_monitoring_connection(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    started = datetime.now(timezone.utc)
    async with prometheus_client(provider_id) as client:
        base_url = await resolve_prometheus(client, provider, nodes)
        if not base_url:
            configured = monitoring_settings(provider_id)["prometheus_url"]
            return {"status": "unavailable", "source": None, "configured": configured, "latency_ms": None,
                    "error": f"{configured or 'Controller와 VIP의 9090 포트'}에서 Prometheus가 응답하지 않습니다."}
        latency_ms = round((datetime.now(timezone.utc) - started).total_seconds() * 1000)
        version = None
        targets_up = targets_total = 0
        error = None
        try:
            build = await client.get(f"{base_url}/api/v1/status/buildinfo")
            if build.status_code == 200:
                version = build.json().get("data", {}).get("version")
        except (httpx.HTTPError, ValueError):
            version = None  # the version is decorative; target counts decide the outcome
        try:
            up = await prom_instant(client, base_url, "up")
            targets_total = len(up)
            targets_up = sum(1 for item in up if (prom_value(item) or 0) >= 1)
        except (httpx.HTTPError, ValueError) as exc:
            error = f"조회 실패: {type(exc).__name__}"
    audit("monitoring.test", "provider", provider_id, provider["name"], f"{base_url} · {latency_ms}ms · 대상 {targets_up}/{targets_total}" + (f" · {error}" if error else ""))
    configured = monitoring_settings(provider_id)["prometheus_url"]
    return {"status": "connected" if not error else "error", "source": base_url, "configured": configured, "fallback": bool(configured) and base_url != configured,
            "version": version, "latency_ms": latency_ms, "targets_up": targets_up, "targets_total": targets_total, "error": error}


def alert_rules(provider_id: str) -> dict:
    stored = provider_setting(provider_id, "alert_rules") or {}
    rules = json.loads(json.dumps(DEFAULT_ALERT_RULES))
    for key, value in stored.items():
        if key in rules:
            rules[key] = {**rules[key], **value} if isinstance(rules[key], dict) and isinstance(value, dict) else value
    return rules


def validate_alert_rules(value: dict) -> dict:
    if not isinstance(value, dict):
        raise HTTPException(400, "규칙은 객체여야 합니다.")
    normalized = json.loads(json.dumps(DEFAULT_ALERT_RULES))
    normalized["enabled"] = bool(value.get("enabled", True))
    try:
        sustained = int(value.get("sustained_minutes", DEFAULT_ALERT_RULES["sustained_minutes"]))
    except (TypeError, ValueError) as exc:
        raise HTTPException(400, "지속 시간은 정수(분)여야 합니다.") from exc
    if not 1 <= sustained <= 120:
        raise HTTPException(400, "지속 시간은 1~120분 범위여야 합니다.")
    normalized["sustained_minutes"] = sustained
    for metric, (minimum, maximum, label) in {"cpu": (1, 100, "CPU"), "memory": (1, 100, "메모리"), "disk": (1, 100, "디스크"), "load_per_core": (0.1, 64, "Core당 Load")}.items():
        pair = value.get(metric, DEFAULT_ALERT_RULES[metric])
        if pair is None or pair is False:
            normalized[metric] = None
            continue
        try:
            warning = float(pair.get("warning")) if isinstance(pair, dict) else float(pair)
            critical = float(pair.get("critical", warning)) if isinstance(pair, dict) else warning
        except (TypeError, ValueError, AttributeError) as exc:
            raise HTTPException(400, f"{label} 임계치는 숫자여야 합니다.") from exc
        if not (minimum <= warning <= maximum and minimum <= critical <= maximum):
            raise HTTPException(400, f"{label} 임계치는 {minimum}~{maximum} 범위여야 합니다.")
        if critical < warning:
            raise HTTPException(400, f"{label} 위험 임계치는 주의 임계치보다 크거나 같아야 합니다.")
        normalized[metric] = {"warning": round(warning, 2), "critical": round(critical, 2)}
    normalized["node_down"] = bool(value.get("node_down", True))
    normalized["target_down"] = bool(value.get("target_down", True))
    return normalized


@app.get("/api/providers/{provider_id}/monitoring/rules")
async def get_monitoring_rules(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    info = get_setting_info(provider_setting_key(provider_id, "alert_rules"))
    return {"value": alert_rules(provider_id), "default": DEFAULT_ALERT_RULES, "source": "stored" if info else "default",
            "updated_at": info["updated_at"] if info else None, "updated_by": info["updated_by"] if info else None,
            "last_evaluation": MONITORING_LAST_EVALUATION.get(provider_id), "interval_seconds": MONITORING_EVALUATOR_INTERVAL}


@app.put("/api/providers/{provider_id}/monitoring/rules")
async def update_monitoring_rules(provider_id: str, payload: AlertRulesRequest, request: Request):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    value = validate_alert_rules(payload.value)
    username = request.state.user["username"] if request.state.user else ""
    set_setting(provider_setting_key(provider_id, "alert_rules"), value, username)
    audit("monitoring.rules.update", "provider", provider_id, provider_label(provider_id), json.dumps(value, ensure_ascii=False)[:500])
    return await get_monitoring_rules(provider_id)


@app.delete("/api/providers/{provider_id}/monitoring/rules")
async def reset_monitoring_rules(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    delete_setting(provider_setting_key(provider_id, "alert_rules"))
    audit("monitoring.rules.reset", "provider", provider_id, provider_label(provider_id), "기본 임계치로 복원")
    return await get_monitoring_rules(provider_id)


def threshold_severity(value: float | None, pair: dict | None) -> str | None:
    if value is None or not pair:
        return None
    if value >= pair["critical"]:
        return "critical"
    if value >= pair["warning"]:
        return "warning"
    return None


async def collect_rule_findings(client: httpx.AsyncClient, base_url: str, provider: dict, nodes: list[dict], rules: dict) -> dict[str, dict]:
    """source_key → alert payload for every rule currently breached, from node_exporter averaged over sustained_minutes."""
    window = f"{rules['sustained_minutes']}m"
    subquery = lambda expr: f"avg_over_time(({expr})[{window}:1m])"  # noqa: E731
    queries = {
        "cpu": subquery(NODE_EXPORTER_QUERIES["cpu"]), "memory": subquery(NODE_EXPORTER_QUERIES["memory"]), "disk": subquery(NODE_EXPORTER_QUERIES["disk"]),
        "load_per_core": f"avg_over_time(node_load1{{job=\"node_exporter\"}}[{window}]) / on(instance) group_left(nodename) {NODE_EXPORTER_QUERIES['cores']}",
        "up": "up",
    }
    results = dict(await asyncio.gather(*(_named(name, prom_instant(client, base_url, query)) for name, query in queries.items())))
    findings: dict[str, dict] = {}
    labels = {"cpu": ("CPU 사용률", "%"), "memory": ("메모리 사용률", "%"), "disk": ("루트 디스크 사용률", "%"), "load_per_core": ("Core당 Load", "")}
    for metric, (label, unit) in labels.items():
        pair = rules.get(metric)
        if not pair:
            continue
        for item in results.get(metric, []):
            hostname = prom_hostname(item.get("metric", {}))
            value = prom_value(item)
            severity = threshold_severity(value, pair)
            if not severity or not hostname:
                continue
            shown = f"{value:.1f}{unit}" if unit else f"{value:.2f}"
            findings[f"monitor:{metric}:{hostname}"] = {
                "severity": severity, "target": hostname, "title": f"{hostname} {label} {shown}",
                "description": f"모니터링 임계치 초과: {label} {shown} (최근 {rules['sustained_minutes']}분 평균, 주의 {pair['warning']}{unit} · 위험 {pair['critical']}{unit}). Prometheus {base_url}",
            }
    inventory_hosts = {node["hostname"].split(".")[0].lower() for node in nodes}
    for item in results.get("up", []):
        item_labels = item.get("metric", {})
        healthy = (prom_value(item) or 0) >= 1
        if healthy:
            continue
        job = item_labels.get("job", "")
        instance = item_labels.get("instance", "")
        hostname = prom_hostname(item_labels)
        if job == "node_exporter" and rules.get("node_down"):
            findings[f"monitor:node_down:{hostname}"] = {
                "severity": "critical", "target": hostname, "title": f"{hostname} node_exporter 응답 없음",
                "description": f"Prometheus가 {instance}의 node_exporter를 수집하지 못합니다(up=0). 노드 다운 또는 exporter 중지 여부를 확인하세요.",
            }
        elif job != "node_exporter" and rules.get("target_down"):
            findings[f"monitor:target_down:{job}:{instance}"] = {
                "severity": "warning", "target": hostname if hostname.split(".")[0].lower() in inventory_hosts else instance, "title": f"수집 대상 DOWN · {job} {instance}",
                "description": f"Prometheus 수집 대상 {job} ({instance})이 응답하지 않습니다(up=0).",
            }
    return findings


async def _named(name: str, coroutine):
    return name, await coroutine


async def evaluate_provider_rules(provider: dict) -> dict:
    provider_id = provider["id"]
    rules = alert_rules(provider_id)
    summary = {"evaluated_at": datetime.now(timezone.utc).isoformat(), "status": "skipped", "source": None, "active": 0, "created": 0, "resolved": 0, "suppressed": 0, "error": None}
    if not rules.get("enabled"):
        summary["status"] = "disabled"
        MONITORING_LAST_EVALUATION[provider_id] = summary
        return summary
    nodes = list_provider_nodes(provider_id)
    try:
        async with prometheus_client(provider_id) as client:
            base_url = await resolve_prometheus(client, provider, nodes)
            if not base_url:
                summary["status"] = "no_prometheus"
                MONITORING_LAST_EVALUATION[provider_id] = summary
                return summary
            summary["source"] = base_url
            findings = await collect_rule_findings(client, base_url, provider, nodes, rules)
    except (httpx.HTTPError, ValueError, KeyError) as exc:
        summary.update(status="error", error=f"{type(exc).__name__}: {exc}"[:200])
        MONITORING_LAST_EVALUATION[provider_id] = summary
        return summary
    active_keys = set()
    for source_key, finding in findings.items():
        active_keys.add(source_key)
        # The store applies maintenance windows (suppressed_until) so a window opened for the node hides the alert.
        outcome = upsert_monitoring_alert(provider_id, source_key, finding["severity"], finding["title"], finding["description"], finding["target"])
        if outcome.get("suppressed_until"):
            summary["suppressed"] += 1
        if outcome.get("created"):
            summary["created"] += 1
            logger.info("Monitoring alert raised for provider %s: %s (%s)", provider_id, finding["title"], finding["severity"])
    for source_key in list_open_monitoring_alert_keys(provider_id) - active_keys:
        if resolve_monitoring_alert(provider_id, source_key, "임계치 이하로 복귀"):
            summary["resolved"] += 1
    summary.update(status="ok", active=len(active_keys))
    MONITORING_LAST_EVALUATION[provider_id] = summary
    return summary


async def evaluate_monitoring_rules_once() -> None:
    for provider in list_providers():
        try:
            await evaluate_provider_rules(provider)
        except Exception:  # noqa: BLE001 - one provider must not stop the others
            logger.exception("Monitoring rule evaluation failed for provider %s", provider["id"])


async def run_monitoring_evaluator():
    await asyncio.sleep(MONITORING_EVALUATOR_INITIAL_DELAY)
    logger.info("Monitoring threshold evaluator started (interval %ss)", MONITORING_EVALUATOR_INTERVAL)
    while True:
        try:
            await evaluate_monitoring_rules_once()
        except Exception:
            logger.exception("Monitoring evaluator iteration failed")
        await asyncio.sleep(MONITORING_EVALUATOR_INTERVAL)


@app.on_event("startup")
async def start_monitoring_evaluator():
    task = asyncio.create_task(run_monitoring_evaluator())
    BACKGROUND_TASKS.add(task)
    task.add_done_callback(BACKGROUND_TASKS.discard)


@app.post("/api/providers/{provider_id}/monitoring/evaluate")
async def evaluate_monitoring_now(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    summary = await evaluate_provider_rules(provider)
    audit("monitoring.evaluate", "provider", provider_id, provider["name"], f"{summary['status']} · 활성 {summary['active']} · 신규 {summary['created']} · 해소 {summary['resolved']}", outcome="failure" if summary["status"] == "error" else "success")
    return summary


def inspection_node_history(provider_id: str, hostname: str, limit: int = 20) -> dict:
    """Per-check CPU/memory/disk of one node from stored inspections (fallback when no Prometheus)."""
    series = {"cpu": [], "memory": [], "disk": []}
    latest = None
    for entry in list_checks(provider_id, limit):
        if entry["summary"].get("nodes", {}).get("total", 0) == 0:
            continue
        full = get_check(provider_id, entry["id"])
        if not full:
            continue
        node = next((item for item in full["result"].get("nodes") or [] if hostname_matches(item.get("hostname", ""), hostname)), None)
        if not node or not node.get("reachable"):
            continue
        timestamp = datetime.fromisoformat(full["checked_at"]).timestamp()
        metrics = node.get("metrics") or {}
        for metric, key in (("cpu", "cpu_used_percent"), ("memory", "memory_used_percent"), ("disk", "disk_used_percent")):
            if isinstance(metrics.get(key), (int, float)):
                series[metric].append([timestamp, round(float(metrics[key]), 1)])
        if latest is None:
            latest = {"checked_at": full["checked_at"], "metrics": metrics, "warnings": node.get("warnings") or [], "status": node.get("status")}
    for metric in series:
        series[metric].sort(key=lambda item: item[0])
    return {"series": series, "latest": latest}


@app.get("/api/providers/{provider_id}/monitoring/nodes/{hostname}")
async def provider_monitoring_node(provider_id: str, hostname: str, range: str = Query(default="6h")):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if range not in MONITORING_RANGES:
        raise HTTPException(400, "지원하지 않는 조회 범위입니다. 1h, 6h, 24h, 7d 중에서 선택하세요.")
    hostname = hostname.strip()[:253]
    seconds, step = MONITORING_RANGES[range]
    nodes = list_provider_nodes(provider_id)
    inventory = next((node for node in nodes if hostname_matches(node["hostname"], hostname, node.get("address", ""))), None)
    address = (inventory or {}).get("address", "")
    prometheus: dict = {"status": "unavailable", "source": None, "error": None}
    async with prometheus_client(provider_id) as client:
        base_url = await resolve_prometheus(client, provider, nodes)
        if base_url:
            try:
                up = await prom_instant(client, base_url, 'up{job="node_exporter"}')
                match = next((item for item in up if hostname_matches(prom_hostname(item.get("metric", {})), hostname, address) or item.get("metric", {}).get("instance", "").split(":")[0] == address), None)
                if not match:
                    prometheus = {"status": "error", "source": base_url, "error": f"{hostname}의 node_exporter 대상을 찾지 못했습니다."}
                else:
                    instance = match["metric"].get("instance", "")
                    selector = f'instance="{instance}"'
                    end = datetime.now(timezone.utc)
                    instant_queries = {
                        "filesystems_size": f'node_filesystem_size_bytes{{{selector},fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}}',
                        "filesystems_avail": f'node_filesystem_avail_bytes{{{selector},fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}}',
                        "net_rx": f'rate(node_network_receive_bytes_total{{{selector},device!~"lo"}}[5m])', "net_tx": f'rate(node_network_transmit_bytes_total{{{selector},device!~"lo"}}[5m])',
                        "net_up": f'node_network_up{{{selector},device!~"lo"}}', "net_speed": f'node_network_speed_bytes{{{selector},device!~"lo"}}',
                        "iowait": f'avg(rate(node_cpu_seconds_total{{{selector},mode="iowait"}}[5m])) * 100', "steal": f'avg(rate(node_cpu_seconds_total{{{selector},mode="steal"}}[5m])) * 100',
                        "swap_total": f'node_memory_SwapTotal_bytes{{{selector}}}', "swap_free": f'node_memory_SwapFree_bytes{{{selector}}}',
                        "fd_allocated": f'node_filefd_allocated{{{selector}}}', "fd_maximum": f'node_filefd_maximum{{{selector}}}',
                        "load1": f'node_load1{{{selector}}}', "load5": f'node_load5{{{selector}}}', "load15": f'node_load15{{{selector}}}',
                        "cores": f'count(node_cpu_seconds_total{{{selector},mode="idle"}})', "uptime": f'time() - node_boot_time_seconds{{{selector}}}',
                        "cpu": f'100 - (avg(rate(node_cpu_seconds_total{{{selector},mode="idle"}}[5m])) * 100)',
                        "memory": f'(1 - node_memory_MemAvailable_bytes{{{selector}}} / node_memory_MemTotal_bytes{{{selector}}}) * 100',
                        "memory_total": f'node_memory_MemTotal_bytes{{{selector}}}', "conntrack": f'node_nf_conntrack_entries{{{selector}}}', "conntrack_limit": f'node_nf_conntrack_entries_limit{{{selector}}}',
                        "procs_running": f'node_procs_running{{{selector}}}', "procs_blocked": f'node_procs_blocked{{{selector}}}',
                    }
                    range_queries = {
                        "cpu": instant_queries["cpu"], "memory": instant_queries["memory"], "iowait": instant_queries["iowait"],
                        "disk_read": f'sum(rate(node_disk_read_bytes_total{{{selector},device!~"loop.*|dm-.*|sr.*"}}[5m]))', "disk_write": f'sum(rate(node_disk_written_bytes_total{{{selector},device!~"loop.*|dm-.*|sr.*"}}[5m]))',
                        "net_rx": f'sum(rate(node_network_receive_bytes_total{{{selector},device!~"lo|veth.*|br.*|docker.*|tap.*|qbr.*|qvb.*|qvo.*"}}[5m]))', "net_tx": f'sum(rate(node_network_transmit_bytes_total{{{selector},device!~"lo|veth.*|br.*|docker.*|tap.*|qbr.*|qvb.*|qvo.*"}}[5m]))',
                        "load1": instant_queries["load1"],
                    }
                    instant_results = dict(await asyncio.gather(*(_named(name, prom_instant(client, base_url, query)) for name, query in instant_queries.items())))
                    range_results = dict(await asyncio.gather(*(_named(name, prom_range(client, base_url, query, seconds, step, end)) for name, query in range_queries.items())))
                    single = lambda name: next((prom_value(item) for item in instant_results.get(name, [])), None)  # noqa: E731
                    filesystems = {}
                    for item in instant_results["filesystems_size"]:
                        mount = item["metric"].get("mountpoint", "")
                        filesystems[mount] = {"mountpoint": mount, "device": item["metric"].get("device", ""), "fstype": item["metric"].get("fstype", ""), "size": prom_value(item), "avail": None}
                    for item in instant_results["filesystems_avail"]:
                        mount = item["metric"].get("mountpoint", "")
                        if mount in filesystems:
                            filesystems[mount]["avail"] = prom_value(item)
                    for entry in filesystems.values():
                        entry["used_percent"] = round((1 - entry["avail"] / entry["size"]) * 100, 1) if entry["size"] and entry["avail"] is not None else None
                    interfaces = {}
                    for name, key in (("net_rx", "rx"), ("net_tx", "tx"), ("net_up", "up"), ("net_speed", "speed")):
                        for item in instant_results.get(name, []):
                            device = item["metric"].get("device", "")
                            interfaces.setdefault(device, {"device": device, "rx": None, "tx": None, "up": None, "speed": None})[key] = prom_value(item)
                    prometheus = {
                        "status": "connected", "source": base_url, "instance": instance, "collected_at": end.isoformat(), "range": range, "step": step,
                        "facts": {"cpu": single("cpu"), "memory": single("memory"), "memory_total": single("memory_total"), "iowait": single("iowait"), "steal": single("steal"),
                                  "swap_total": single("swap_total"), "swap_free": single("swap_free"), "fd_allocated": single("fd_allocated"), "fd_maximum": single("fd_maximum"),
                                  "load1": single("load1"), "load5": single("load5"), "load15": single("load15"), "cores": single("cores"), "uptime": single("uptime"),
                                  "conntrack": single("conntrack"), "conntrack_limit": single("conntrack_limit"), "procs_running": single("procs_running"), "procs_blocked": single("procs_blocked")},
                        "filesystems": sorted(filesystems.values(), key=lambda entry: -(entry["used_percent"] or 0)),
                        "interfaces": sorted(interfaces.values(), key=lambda entry: -((entry["rx"] or 0) + (entry["tx"] or 0))),
                        "series": {name: prom_points(result) for name, result in range_results.items()},
                    }
            except (httpx.HTTPError, ValueError, KeyError) as exc:
                prometheus = {"status": "error", "source": base_url, "error": f"Prometheus 조회 실패: {type(exc).__name__}"}
    inspection = await asyncio.to_thread(inspection_node_history, provider_id, hostname, 20)
    return {"provider": {"id": provider["id"], "name": provider["name"]}, "hostname": hostname, "inventory": inventory, "range": range, "prometheus": prometheus, "inspection": inspection}


async def probe_openstack_api(client: httpx.AsyncClient, vip: str, key: str, label: str, port: int) -> dict:
    result = {"key": key, "label": label, "port": port, "reachable": False, "status_code": None, "latency_ms": None, "scheme": None, "error": None}
    for scheme in ("http", "https"):
        started = datetime.now(timezone.utc)
        try:
            response = await client.get(f"{scheme}://{vip}:{port}/")
        except httpx.ConnectError as exc:
            result["error"] = f"연결 실패 ({type(exc).__name__})"
            continue
        except httpx.HTTPError as exc:
            result["error"] = f"{type(exc).__name__}"
            continue
        result.update(reachable=True, status_code=response.status_code, latency_ms=round((datetime.now(timezone.utc) - started).total_seconds() * 1000), scheme=scheme, error=None)
        break
    return result


@app.get("/api/providers/{provider_id}/monitoring/openstack")
async def provider_monitoring_openstack(provider_id: str):
    """OpenStack API reachability from the platform host plus HAProxy/RabbitMQ/Galera exporter metrics when Prometheus has them."""
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    async with httpx.AsyncClient(timeout=3, verify=False, follow_redirects=False) as probe_client:
        probes = await asyncio.gather(*(probe_openstack_api(probe_client, provider["vip"], key, label, port) for key, label, port in OPENSTACK_API_PORTS))
    haproxy = {"status": "no_source", "backends": [], "note": "haproxy_exporter 수집원 없음"}
    rabbitmq = {"status": "no_source", "note": "rabbitmq_exporter 수집원 없음"}
    galera = {"status": "no_source", "note": "mysqld_exporter 수집원 없음"}
    source = None
    async with prometheus_client(provider_id) as client:
        base_url = await resolve_prometheus(client, provider, nodes)
        if base_url:
            source = base_url
            try:
                backend_up, server_up = await asyncio.gather(prom_instant(client, base_url, "haproxy_backend_up"), prom_instant(client, base_url, "haproxy_server_up"))
                if backend_up or server_up:
                    backends: dict[str, dict] = {}
                    for item in backend_up:
                        name = item["metric"].get("backend") or item["metric"].get("proxy", "")
                        backends[name] = {"backend": name, "up": (prom_value(item) or 0) >= 1, "servers": []}
                    for item in server_up:
                        name = item["metric"].get("backend") or item["metric"].get("proxy", "")
                        backends.setdefault(name, {"backend": name, "up": None, "servers": []})["servers"].append({"server": item["metric"].get("server", ""), "up": (prom_value(item) or 0) >= 1})
                    for entry in backends.values():
                        entry["servers_up"] = sum(1 for server in entry["servers"] if server["up"])
                        entry["servers_total"] = len(entry["servers"])
                    haproxy = {"status": "ok", "backends": sorted(backends.values(), key=lambda entry: (entry["up"] is not False, entry["backend"])), "note": None}
                ready, unacked, queues, rabbit_up = await asyncio.gather(
                    prom_instant(client, base_url, "sum(rabbitmq_queue_messages_ready)"), prom_instant(client, base_url, "sum(rabbitmq_queue_messages_unacked or rabbitmq_queue_messages_unacknowledged)"),
                    prom_instant(client, base_url, "count(rabbitmq_queue_messages_ready)"), prom_instant(client, base_url, "rabbitmq_up or rabbitmq_build_info"))
                if ready or rabbit_up:
                    rabbitmq = {"status": "ok", "note": None, "messages_ready": next((prom_value(item) for item in ready), 0), "messages_unacked": next((prom_value(item) for item in unacked), 0),
                                "queues": next((prom_value(item) for item in queues), 0), "nodes": [{"instance": item["metric"].get("instance", ""), "up": (prom_value(item) or 0) >= 1} for item in rabbit_up]}
                wsrep = await asyncio.gather(prom_instant(client, base_url, "mysql_global_status_wsrep_cluster_size"), prom_instant(client, base_url, "mysql_global_status_wsrep_local_state"),
                                             prom_instant(client, base_url, "mysql_global_status_wsrep_local_recv_queue"), prom_instant(client, base_url, "mysql_global_status_wsrep_flow_control_paused"), prom_instant(client, base_url, "mysql_up"))
                if wsrep[0] or wsrep[4]:
                    states = {1: "Joining", 2: "Donor/Desynced", 3: "Joined", 4: "Synced"}
                    galera = {"status": "ok", "note": None, "cluster_size": next((prom_value(item) for item in wsrep[0]), None),
                              "nodes": [{"instance": item["metric"].get("instance", ""), "state": states.get(int(prom_value(item) or 0), str(prom_value(item))),
                                         "recv_queue": next((prom_value(entry) for entry in wsrep[2] if entry["metric"].get("instance") == item["metric"].get("instance")), None),
                                         "flow_control_paused": next((prom_value(entry) for entry in wsrep[3] if entry["metric"].get("instance") == item["metric"].get("instance")), None)} for item in wsrep[1]],
                              "mysql_up": [{"instance": item["metric"].get("instance", ""), "up": (prom_value(item) or 0) >= 1} for item in wsrep[4]]}
            except (httpx.HTTPError, ValueError, KeyError) as exc:
                haproxy["note"] = rabbitmq["note"] = galera["note"] = f"Prometheus 조회 실패: {type(exc).__name__}"
    return {"provider": {"id": provider["id"], "name": provider["name"], "vip": provider["vip"]}, "collected_at": datetime.now(timezone.utc).isoformat(), "source": source,
            "api": list(probes), "api_reachable": sum(1 for probe in probes if probe["reachable"]), "haproxy": haproxy, "rabbitmq": rabbitmq, "galera": galera}


async def resolve_alertmanager(client: httpx.AsyncClient, provider: dict, nodes: list[dict]) -> str | None:
    configured = monitoring_settings(provider["id"])["alertmanager_url"]
    candidates = [configured] if configured else []
    for node in nodes:
        if node["role"] == "controller":
            target = node["address"] if is_ip_address(node.get("address") or "") else node["hostname"]
            candidates.append(f"http://{target}:9093")
    candidates.append(f"http://{provider['vip']}:9093")
    for candidate in candidates:
        try:
            response = await client.get(f"{candidate}/-/ready")
            if response.status_code == 200:
                return candidate
        except httpx.HTTPError:
            continue
    return None


@app.get("/api/providers/{provider_id}/monitoring/alertmanager")
async def provider_monitoring_alertmanager(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    async with prometheus_client(provider_id, timeout=5) as client:
        base_url = await resolve_alertmanager(client, provider, nodes)
        if not base_url:
            return {"status": "unavailable", "source": None, "alerts": [], "note": "Alertmanager를 찾지 못했습니다(설정 주소 또는 Controller 9093)."}
        try:
            response = await client.get(f"{base_url}/api/v2/alerts", params={"active": "true", "silenced": "false", "inhibited": "false"})
            response.raise_for_status()
            raw = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            return {"status": "error", "source": base_url, "alerts": [], "note": f"Alertmanager 조회 실패: {type(exc).__name__}"}
    alerts = []
    for item in raw if isinstance(raw, list) else []:
        labels = item.get("labels", {})
        annotations = item.get("annotations", {})
        alerts.append({"name": labels.get("alertname", "-"), "severity": labels.get("severity", ""), "instance": labels.get("instance", "") or labels.get("nodename", ""), "job": labels.get("job", ""),
                       "state": item.get("status", {}).get("state", ""), "starts_at": item.get("startsAt"), "summary": annotations.get("summary") or annotations.get("description") or annotations.get("message", ""),
                       "labels": {key: value for key, value in labels.items() if key not in {"alertname", "severity", "instance", "job", "nodename"}}})
    order = {"critical": 0, "error": 1, "warning": 2, "info": 3}
    alerts.sort(key=lambda alert: (order.get(alert["severity"], 4), alert["starts_at"] or ""))
    return {"status": "connected", "source": base_url, "alerts": alerts[:200], "total": len(alerts), "note": None}


@app.get("/api/providers/{provider_id}/monitoring/query")
async def provider_monitoring_query(provider_id: str, expr: str = Query(..., min_length=1, max_length=2000), mode: str = Query("instant"), range: str = Query("6h")):
    """Read-only PromQL proxy for the monitoring page's query box."""
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    if mode not in {"instant", "range"}:
        raise HTTPException(400, "mode는 instant 또는 range여야 합니다.")
    if range not in MONITORING_RANGES:
        raise HTTPException(400, "지원하지 않는 조회 범위입니다. 1h, 6h, 24h, 7d 중에서 선택하세요.")
    nodes = list_provider_nodes(provider_id)
    started = datetime.now(timezone.utc)
    async with prometheus_client(provider_id, timeout=20) as client:
        base_url = await resolve_prometheus(client, provider, nodes)
        if not base_url:
            raise HTTPException(503, "Prometheus에 연결할 수 없습니다. 수집원 설정을 확인하세요.")
        try:
            if mode == "instant":
                response = await client.get(f"{base_url}/api/v1/query", params={"query": expr})
            else:
                seconds, step = MONITORING_RANGES[range]
                response = await client.get(f"{base_url}/api/v1/query_range", params={"query": expr, "start": (started - timedelta(seconds=seconds)).timestamp(), "end": started.timestamp(), "step": step})
            body = response.json()
        except httpx.HTTPError as exc:
            raise HTTPException(502, f"Prometheus 조회 실패: {type(exc).__name__}") from exc
        except ValueError as exc:
            raise HTTPException(502, "Prometheus 응답을 해석하지 못했습니다.") from exc
    if body.get("status") != "success":
        raise HTTPException(400, f"PromQL 오류: {body.get('error', response.status_code)}")
    data = body.get("data", {})
    result = data.get("result", [])
    truncated = len(result) > 50
    result = result[:50]
    if mode == "range":
        result = [{"metric": item.get("metric", {}), "values": [[float(ts), value] for ts, value in item.get("values", [])[:2000]]} for item in result]
    return {"mode": mode, "range": range, "result_type": data.get("resultType"), "result": result, "truncated": truncated, "source": base_url,
            "latency_ms": round((datetime.now(timezone.utc) - started).total_seconds() * 1000)}


@app.post("/api/providers/keystone/test")
async def test_keystone(request: KeystoneRequest):
    token_url = request.auth_url if request.auth_url.endswith("/auth/tokens") else f"{request.auth_url}/auth/tokens"
    payload = {"auth": {"identity": {"methods": ["password"], "password": {"user": {
        "name": request.username, "domain": {"name": request.user_domain}, "password": request.password,
    }}}, "scope": {"project": {"name": request.project_name, "domain": {"name": request.project_domain}}}}}
    try:
        async with httpx.AsyncClient(verify=request.verify_tls, timeout=12, follow_redirects=False) as client:
            response = await client.post(token_url, json=payload, headers={"Accept": "application/json"})
    except httpx.ConnectError as exc:
        raise HTTPException(502, "Keystone 서버에 연결할 수 없습니다. URL과 TLS 인증서를 확인하세요.") from exc
    except httpx.TimeoutException as exc:
        raise HTTPException(504, "Keystone 연결 시간이 초과되었습니다.") from exc
    if response.status_code not in {200, 201}:
        messages = {400: "인증 요청 형식이 올바르지 않습니다.", 401: "사용자명 또는 비밀번호가 올바르지 않습니다.", 403: "해당 프로젝트에 접근할 권한이 없습니다.", 404: "Keystone v3 인증 주소를 찾을 수 없습니다."}
        raise HTTPException(response.status_code if response.status_code in messages else 502, messages.get(response.status_code, f"Keystone 인증에 실패했습니다. (HTTP {response.status_code})"))
    if not response.headers.get("X-Subject-Token"):
        raise HTTPException(502, "Keystone 응답에 인증 토큰이 없습니다.")
    try:
        token = response.json()["token"]
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(502, "Keystone 응답을 해석할 수 없습니다.") from exc
    services = []
    regions = set()
    for service in token.get("catalog", []):
        endpoints = []
        for endpoint in service.get("endpoints", []):
            region = endpoint.get("region") or endpoint.get("region_id")
            if region:
                regions.add(region)
            if request.region and region != request.region:
                continue
            endpoints.append({"interface": endpoint.get("interface"), "region": region, "url": endpoint.get("url")})
        if endpoints:
            services.append({"type": service.get("type"), "name": service.get("name"), "endpoints": endpoints})
    return {"status": "authenticated", "project": token.get("project", {}).get("name"), "user": token.get("user", {}).get("name"), "expires_at": token.get("expires_at"), "regions": sorted(regions), "services": services, "tls_verified": request.verify_tls}


@app.get("/")
async def dashboard(): return FileResponse(BASE_DIR / "index.html", headers={"Cache-Control": "no-store, max-age=0"})

@app.get("/providers")
async def providers():
    # The provider screen lives inside the single-page app since 2026-09-03; keep the old address working.
    return RedirectResponse("/#providers", status_code=302, headers={"Cache-Control": "no-store"})

@app.get("/login")
async def login_page(request: Request):
    if request.state.user:
        return RedirectResponse("/", status_code=302, headers={"Cache-Control": "no-store"})
    return FileResponse(BASE_DIR / "login.html", headers={"Cache-Control": "no-store, max-age=0"})

@app.get("/js/{asset_name}")
async def static_script(asset_name: str):
    # Screen scripts live in js/ and are loaded in the order index.html lists them.
    path = BASE_DIR / "js" / asset_name
    if "/" in asset_name or not asset_name.endswith(".js") or not path.is_file():
        raise HTTPException(404)
    return FileResponse(path, media_type="text/javascript", headers={"Cache-Control": "no-store, max-age=0"})

FONT_MEDIA_TYPES = {".woff2": "font/woff2", ".css": "text/css"}


@app.get("/fonts/{asset_name}")
async def static_font(asset_name: str):
    # Inter/Noto Sans KR 는 폐쇄망에서 Google Fonts 를 받을 수 없으므로 이미지에 넣어 직접 제공한다.
    suffix = Path(asset_name).suffix
    path = BASE_DIR / "fonts" / "web" / asset_name
    if "/" in asset_name or suffix not in FONT_MEDIA_TYPES or not path.is_file():
        raise HTTPException(404)
    return FileResponse(path, media_type=FONT_MEDIA_TYPES[suffix], headers={"Cache-Control": "public, max-age=31536000, immutable"})


@app.get("/{asset_name}")
async def static_asset(asset_name: str):
    if asset_name not in {"styles.css", "login.js"}:
        raise HTTPException(404)
    return FileResponse(BASE_DIR / asset_name, headers={"Cache-Control": "no-store, max-age=0"})
