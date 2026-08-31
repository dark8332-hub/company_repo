import asyncio
import base64
import ipaddress
import logging
import os
import re
import shlex
import socket
import uuid
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import asyncssh
import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel, Field, model_validator, field_validator
from inspection_report import build_inspection_pdf
from provider_store import (
    database_credentials_status, delete_check_exception, delete_database_credentials, delete_provider, delete_provider_host_key, get_provider, latest_check, list_check_exceptions,
    is_provider_host_key_trusted, list_host_key_events, list_provider_host_keys, list_provider_nodes,
    list_providers, mark_provider_host_key_seen, save_check, save_check_exception, save_provider,
    save_database_credentials, save_provider_nodes, trust_provider_host_key,
    delete_work_history, get_work_history, list_work_histories, save_work_history, update_work_history,
    alert_summary, get_alert, list_alerts, sync_check_alerts, update_alert,
    delete_custom_check, list_custom_checks, save_custom_check,
    check_summary, get_check, get_check_schedule, list_checks, list_enabled_check_schedules, previous_check_summary,
    record_schedule_run, save_check_schedule,
)

BASE_DIR = Path(__file__).resolve().parent
app = FastAPI(title="OKESTRO OpenStack Operations API", version="0.1.0")
CHECK_PROGRESS: dict[str, dict] = {}
BACKGROUND_TASKS: set[asyncio.Task] = set()
logger = logging.getLogger("uvicorn.error")


def schedule_timezone() -> ZoneInfo:
    """Scheduled checks follow the operators' clock (default Asia/Seoul), not the container's UTC clock."""
    try:
        return ZoneInfo(os.environ.get("INSPECTION_TIMEZONE", "Asia/Seoul"))
    except Exception:
        return ZoneInfo("UTC")

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
    operator: str = Field(min_length=1, max_length=100)
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
        if value not in {"planned", "in_progress", "completed", "failed"}:
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
async def health():
    return {"status": "ok"}


def validated_work_history(request: WorkHistoryRequest) -> dict:
    data = request.model_dump(mode="json")
    for key in ("title", "operator", "target", "ticket", "description", "commands", "before_state", "after_state", "result", "follow_up"):
        data[key] = data[key].strip()
    if request.provider_id and not get_provider(request.provider_id):
        raise HTTPException(400, "등록된 공급자를 찾을 수 없습니다.")
    return data


@app.get("/api/work-histories")
async def work_history_list(provider_id: str = "", work_type: str = "", status: str = "", q: str = Query(default="", max_length=200)):
    return {"histories": list_work_histories(provider_id, work_type, status, q.strip())}


@app.post("/api/work-histories", status_code=201)
async def create_work_history(request: WorkHistoryRequest):
    return save_work_history(validated_work_history(request))


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
    return history


@app.delete("/api/work-histories/{history_id}")
async def remove_work_history(history_id: str):
    if not delete_work_history(history_id):
        raise HTTPException(404, "작업 이력을 찾을 수 없습니다.")
    return {"status": "deleted"}


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
    alert = update_alert(alert_id, request.status, request.assignee.strip(), request.resolution_note.strip(), request.work_history_id)
    if not alert:
        raise HTTPException(404, "알림을 찾을 수 없습니다.")
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
    return ([host_key], [], [], [], [], [], [])


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
                "printf 'hostname='; hostname; "
                "printf 'user='; id -un; "
                "if sudo -n true >/dev/null 2>&1; then echo 'sudo=passwordless'; else echo 'sudo=authentication_required'; fi; "
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
            return {
                "status": "connected", "fingerprint": fingerprint,
                "controller_hostname": probe.get("hostname", "unknown"),
                "ssh_user": probe.get("user", request.username),
                "sudo_mode": probe.get("sudo", "unknown"),
                "available_tools": tools,
                "provider_id": save_provider({
                    "name": request.provider_name, "vip": request.vip, "port": request.port,
                    "username": request.username, "auth_method": request.auth_method,
                    "fingerprint": fingerprint, "controller_hostname": probe.get("hostname", "unknown"),
                    "sudo_mode": probe.get("sudo", "unknown"), "available_tools": tools,
                }, {"private_key": request.private_key, "passphrase": request.passphrase, "password": request.password}),
            }
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
    return {"status": "saved", **database_credentials_status(provider_id)}


@app.delete("/api/providers/{provider_id}/database-credentials")
async def remove_provider_database_credentials(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    delete_database_credentials(provider_id)
    return {"status": "deleted", "configured": False}


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


@app.get("/api/providers/{provider_id}/nodes")
async def provider_nodes(provider_id: str):
    if not get_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    return {"provider_id": provider_id, "nodes": nodes, "count": len(nodes)}


@app.post("/api/providers/{provider_id}/discover")
async def discover_provider_nodes(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    host_key, fingerprint = await scan_ssh_host_key(provider["vip"], provider["port"])
    if not is_provider_host_key_trusted(provider_id, fingerprint):
        raise HTTPException(409, detail={
            "code": "host_key_approval_required", "message": "새 SSH 호스트 키 승인이 필요합니다.",
            "fingerprint": fingerprint,
        })
    options = provider_ssh_options(provider)
    options["known_hosts"] = trusted_known_hosts(host_key)
    command = r'''
printf 'controller=%s|active-vip\n' "$(hostname -s)"
if command -v pcs >/dev/null 2>&1; then
  pcs status nodes 2>/dev/null | awk '/Online:/{line=$0; sub(/^.*Online:[[:space:]]*\[/,"",line); sub(/\].*$/,"",line); count=split(line,nodes,/ +/); for(i=1;i<=count;i++) if(nodes[i]!="") print "controller=" nodes[i] "|pcs"}'
fi
openrc_source=""
for candidate in "$HOME/contrabass-openrc" "$HOME/admin-openrc.sh" "$HOME/openrc" /etc/kolla/admin-openrc.sh /root/contrabass-openrc /root/admin-openrc.sh /root/keystonerc_admin; do
  if [ -r "$candidate" ]; then . "$candidate" >/dev/null 2>&1 && openrc_source="$candidate" && break; fi
done
if command -v openstack >/dev/null 2>&1; then
  openstack compute service list --service nova-compute -f value -c Host 2>/dev/null | awk 'NF{print "compute=" $1 "|openstack"}'
  [ -n "$openrc_source" ] && printf 'meta=openrc|%s\n' "$openrc_source"
else
  printf 'warning=openstack CLI를 찾을 수 없습니다.\n'
fi
exit 0
'''
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            mark_provider_host_key_seen(provider_id, fingerprint)
            response = await connection.run(command, check=False, timeout=30)
    except HTTPException:
        raise
    except (asyncssh.Error, OSError) as exc:
        raise HTTPException(502, f"클러스터 탐색 연결에 실패했습니다: {type(exc).__name__}") from exc
    if response.exit_status != 0:
        raise HTTPException(502, "클러스터 노드 탐색 명령 실행에 실패했습니다.")
    discovered = {}
    warnings = []
    sources = set()
    for line in response.stdout.splitlines():
        if line.startswith("warning="):
            warnings.append(line.split("=", 1)[1])
            continue
        if line.startswith("meta=openrc|"):
            sources.add(f"OpenRC: {line.split('|', 1)[1]}")
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
    for node in discovered.values():
        if node["hostname"].split(".")[0] == active_hostname:
            node["address"] = provider["vip"]
            node["source"] = "active-vip" if node["source"] == "active-vip" else node["source"]
    nodes = list(discovered.values())
    save_provider_nodes(provider_id, nodes)
    if not any(node["role"] == "compute" for node in nodes):
        warnings.append("Compute 노드를 찾지 못했습니다. Controller의 OpenStack 인증 환경을 확인하세요.")
    return {"provider_id": provider_id, "nodes": nodes, "count": len(nodes), "sources": sorted(sources), "warnings": warnings}


@app.delete("/api/providers/{provider_id}")
async def remove_provider(provider_id: str):
    if not delete_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
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
    return save_custom_check(provider_id, request.model_dump())


@app.put("/api/providers/{provider_id}/custom-checks/{check_id}")
async def edit_custom_check(provider_id: str, check_id: str, request: CustomCheckRequest):
    if not any(item["id"] == check_id for item in list_custom_checks(provider_id)):
        raise HTTPException(404, "사용자 정의 점검을 찾을 수 없습니다.")
    return save_custom_check(provider_id, request.model_dump(), check_id)


@app.delete("/api/providers/{provider_id}/custom-checks/{check_id}")
async def remove_custom_check(provider_id: str, check_id: str):
    if not delete_custom_check(provider_id, check_id):
        raise HTTPException(404, "사용자 정의 점검을 찾을 수 없습니다.")
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
        options["known_hosts"] = "/root/.ssh/known_hosts"
        try:
            address = await asyncio.to_thread(socket.gethostbyname, node["hostname"])
            async with asyncssh.connect(address, **options) as connection:
                command = definition["command"]
                if definition.get("execution_context") == "openstack":
                    safe_command = " ".join(shlex.quote(part) for part in validate_custom_command(command))
                    command = """openrc=''; for candidate in /root/contrabass-openrc \"$HOME/contrabass-openrc\"; do if [ -r \"$candidate\" ]; then openrc=\"$candidate\"; break; fi; done; if [ -z \"$openrc\" ]; then echo 'OpenStack OpenRC 파일을 찾을 수 없습니다.' >&2; exit 78; fi; . \"$openrc\" >/dev/null 2>&1 || { echo 'OpenStack OpenRC 적용에 실패했습니다.' >&2; exit 78; }; """ + safe_command
                response = await connection.run(command, check=False, timeout=definition["timeout_seconds"])
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
        except (asyncssh.Error, OSError, TimeoutError) as exc:
            return {"hostname": node["hostname"], "role": node["role"], "status": "unavailable", "output": type(exc).__name__}

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
    return save_check_exception(provider_id, request.item_key, reason, node_hostname)


@app.delete("/api/providers/{provider_id}/check-exceptions/{exception_id}")
async def remove_check_exception(provider_id: str, exception_id: str):
    if not delete_check_exception(provider_id, exception_id):
        raise HTTPException(404, "예외 규칙을 찾을 수 없습니다.")
    return {"status": "deleted"}


@app.post("/api/providers/{provider_id}/checks")
async def run_provider_check(provider_id: str, request: CheckRequest | None = None, trigger: str = "manual"):
    """Run one inspection per provider at a time and always leave a terminal progress state behind."""
    if CHECK_PROGRESS.get(provider_id, {}).get("running"):
        raise HTTPException(409, "이미 이 공급자의 일일점검이 실행 중입니다. 완료 후 다시 실행하세요.")
    started = datetime.now(timezone.utc)
    try:
        return await execute_provider_check(provider_id, request, trigger, started)
    except HTTPException as exc:
        if CHECK_PROGRESS.get(provider_id, {}).get("running"):
            CHECK_PROGRESS[provider_id] = {"running": False, "stage": "failed", "message": f"점검 실패: {exc.detail}", "current_items": [], "percent": 0,
                                           "started_at": started.isoformat(), "updated_at": datetime.now(timezone.utc).isoformat()}
        raise
    except Exception as exc:
        CHECK_PROGRESS[provider_id] = {"running": False, "stage": "failed", "message": f"점검 실패: {type(exc).__name__}", "current_items": [], "percent": 0,
                                       "started_at": started.isoformat(), "updated_at": datetime.now(timezone.utc).isoformat()}
        raise HTTPException(500, f"점검 실행 중 오류가 발생했습니다: {type(exc).__name__}") from exc


async def execute_provider_check(provider_id: str, request: CheckRequest | None, trigger: str, started: datetime):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    if not nodes:
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
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
    def update_progress(stage: str, message: str, current_items: set[str] | list[str], percent: int, running: bool = True):
        CHECK_PROGRESS[provider_id] = {
            "running": running, "stage": stage, "message": message, "current_items": sorted(current_items),
            "percent": percent, "updated_at": datetime.now(timezone.utc).isoformat(), "started_at": started.isoformat(), "trigger": trigger,
        }
    update_progress("preparing", "점검 대상과 SSH 연결을 준비하고 있습니다.", selected_items, 5)
    selected_shell = shlex.quote("|" + "|".join(sorted(selected_items)) + "|")

    node_command = f"SELECTED_ITEMS={selected_shell}\n" + r'''
LC_ALL=C
wanted() { case "$SELECTED_ITEMS" in *"|$1|"*) return 0;; *) return 1;; esac; }
emit_raw() { raw_key="$1"; shift; wanted "$raw_key" || return; raw_output=$("$@" 2>&1); raw_encoded=$(printf '%s' "$raw_output" | base64 -w0 2>/dev/null); printf '%s_raw=%s\n' "$raw_key" "$raw_encoded"; }
emit_node_check() { check_key="$1"; check_command="$2"; bad_pattern="$3"; wanted "$check_key" || return; check_output=$(eval "$check_command" 2>&1); check_rc=$?; if [ $check_rc -ne 0 ]; then check_state=unavailable; elif [ -n "$bad_pattern" ] && printf '%s\n' "$check_output" | grep -Eiq "$bad_pattern"; then check_state=warning; else check_state=healthy; fi; check_encoded=$(printf '%s' "$check_output" | base64 -w0 2>/dev/null); printf '%s=%s\n%s_raw=%s\n' "$check_key" "$check_state" "$check_key" "$check_encoded"; }
printf 'hostname=%s\n' "$(hostname -s)"
printf 'uptime_seconds=%s\n' "$(cut -d. -f1 /proc/uptime)"
printf 'cpu_cores=%s\n' "$(getconf _NPROCESSORS_ONLN)"
top -bn1 2>/dev/null | awk '/Cpu\(s\)|%Cpu/{for(i=1;i<=NF;i++)if($i ~ /id/){gsub(/[^0-9.]/,"",$(i-1)); printf "cpu_used_percent=%.1f\n",100-$(i-1); exit}}'
awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2}END{printf "memory_total_kb=%s\nmemory_used_kb=%s\n",t,t-a}' /proc/meminfo
df -Pk / | awk 'NR==2{gsub(/%/,"",$5); printf "disk_total_kb=%s\ndisk_used_kb=%s\ndisk_used_percent=%s\n",$2,$3,$5}'
if command -v chronyc >/dev/null 2>&1; then chronyc tracking >/dev/null 2>&1 && echo chrony=healthy || echo chrony=warning; else echo chrony=unavailable; fi
if [ -d /proc/net/bonding ] && find /proc/net/bonding -type f -maxdepth 1 | grep -q .; then grep -h 'MII Status: down' /proc/net/bonding/* >/dev/null 2>&1 && echo bonding=warning || echo bonding=healthy; else echo bonding=unavailable; fi
mount_count=0; for path in /var/lib/glance/images /var/lib/cinder/conversion /var/lib/cinder/mnt; do [ -e "$path" ] && mount_count=$((mount_count+1)); done
[ "$mount_count" -gt 0 ] && echo mount=healthy || echo mount=unavailable
if systemctl is-active --quiet openstack-nova-compute 2>/dev/null || systemctl is-active --quiet nova-compute 2>/dev/null || pgrep -f '[n]ova-compute' >/dev/null 2>&1; then echo nova_compute=healthy; else echo nova_compute=warning; fi
emit_raw cpu sh -c 'top -bn1 | head -n 12'
emit_raw memory free -h
emit_raw disk df -h /
emit_raw chrony sh -c 'chronyc sources -v; echo; chronyc tracking'
if [ -d /proc/net/bonding ]; then emit_raw bonding sh -c 'cat /proc/net/bonding/*'; else echo bonding_raw=; fi
emit_raw mount sh -c 'mount | grep -E "/var/lib/(glance|cinder)" || true'
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
check_service_log() {
  service="$1"
  wanted "${service}_log" || return
  directory="/var/log/$service"
  if [ ! -d "$directory" ] || ! find "$directory" -maxdepth 1 -type f -name '*.log*' -print -quit 2>/dev/null | grep -q .; then
    printf '%s_log=unavailable\n%s_log_count=0\n' "$service" "$service"
    return
  fi
  yesterday_iso=$(date -d yesterday +%Y-%m-%d)
  yesterday_syslog=$(LC_ALL=C date -d yesterday '+%b %e')
  previous_iso=$(date -d '2 days ago' +%Y-%m-%d)
  previous_syslog=$(LC_ALL=C date -d '2 days ago' '+%b %e')
  read_service_logs() { for log_file in "$directory"/*.log*; do [ -f "$log_file" ] || continue; case "$log_file" in *.gz) gzip -cd -- "$log_file" 2>/dev/null;; *) cat -- "$log_file" 2>/dev/null;; esac; done; }
  matches=$(read_service_logs | awk -v iso="$yesterday_iso" -v syslog="$yesterday_syslog" 'index($0,iso)==1 || index($0,syslog)==1' | grep -Ei 'ERROR|CRITICAL|Traceback|Exception|Failed' | tail -n 100)
  previous_matches=$(read_service_logs | awk -v iso="$previous_iso" -v syslog="$previous_syslog" 'index($0,iso)==1 || index($0,syslog)==1' | grep -Ei 'ERROR|CRITICAL|Traceback|Exception|Failed' | tail -n 100)
  count=$(printf '%s\n' "$matches" | awk 'NF{n++}END{print n+0}')
  sample=$(printf '%s' "$matches" | base64 -w0 2>/dev/null)
  previous_sample=$(printf '%s' "$previous_matches" | base64 -w0 2>/dev/null)
  [ "$count" -gt 0 ] && state=warning || state=healthy
  printf '%s_log=%s\n%s_log_count=%s\n%s_log_date=%s\n%s_previous_log_date=%s\n%s_log_sample=%s\n%s_previous_log_sample=%s\n' "$service" "$state" "$service" "$count" "$service" "$yesterday_iso" "$service" "$previous_iso" "$service" "$sample" "$service" "$previous_sample"
}
for service in nova neutron cinder glance manila octavia masakari swift heat; do check_service_log "$service"; done
system_files=""
for file in /var/log/syslog /var/log/messages; do [ -f "$file" ] && system_files="$system_files $file"; done
if [ -z "$system_files" ]; then
  echo system_log=unavailable
  echo system_log_count=0
else
  yesterday_iso=$(date -d yesterday +%Y-%m-%d)
  yesterday_syslog=$(LC_ALL=C date -d yesterday '+%b %e')
  matches=$(awk -v iso="$yesterday_iso" -v syslog="$yesterday_syslog" 'index($0,iso)==1 || index($0,syslog)==1' $system_files 2>/dev/null | grep -E 'ERROR|CRITICAL|Traceback' | tail -n 100)
  count=$(printf '%s\n' "$matches" | awk 'NF{n++}END{print n+0}')
  sample=$(printf '%s' "$matches" | base64 -w0 2>/dev/null)
  [ "$count" -gt 0 ] && state=warning || state=healthy
  printf 'system_log=%s\nsystem_log_count=%s\nsystem_log_date=%s\nsystem_log_sample=%s\n' "$state" "$count" "$yesterday_iso" "$sample"
fi
'''

    async def check_node(node: dict) -> dict:
        options = provider_ssh_options(provider)
        options["known_hosts"] = "/root/.ssh/known_hosts"
        try:
            address = await asyncio.to_thread(socket.gethostbyname, node["hostname"])
            async with asyncssh.connect(address, **options) as connection:
                # Controllers inspect several large OpenStack log directories in
                # addition to system resources.  A 25-second limit caused the
                # complete node result to be discarded before log scans finished.
                response = await connection.run(node_command, check=False, timeout=120)
                fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if response.exit_status != 0:
                raise RuntimeError("점검 명령 실패")
            values = {}
            for line in response.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    values[key] = value
            integer_keys = {"uptime_seconds", "cpu_cores", "memory_total_kb", "memory_used_kb", "disk_total_kb", "disk_used_kb", "disk_used_percent"}
            integer_keys.update(f"{service}_log_count" for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "masakari", "swift", "heat", "system"))
            for key in integer_keys:
                try: values[key] = int(values[key])
                except (KeyError, ValueError): pass
            try: values["cpu_used_percent"] = float(values["cpu_used_percent"])
            except (KeyError, ValueError): values["cpu_used_percent"] = None
            values["memory_used_percent"] = round(values.get("memory_used_kb", 0) / max(values.get("memory_total_kb", 1), 1) * 100, 1)
            for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "masakari", "swift", "heat", "system"):
                for sample_key in (f"{service}_log_sample", f"{service}_previous_log_sample"):
                    encoded = values.pop(sample_key, "")
                    try: values[sample_key] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                    except ValueError: values[sample_key] = ""
            for key in ("cpu", "memory", "disk", "chrony", "bonding", "mount", "nova_compute", "virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration", "libvirt_state", "instance_storage", "smart_health", "raid_health"):
                encoded = values.pop(f"{key}_raw", "")
                try: values[f"{key}_raw"] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: values[f"{key}_raw"] = ""
            warnings = []
            if "cpu" in selected_items and values.get("cpu_used_percent") is not None and values["cpu_used_percent"] >= 80: warnings.append("CPU 사용률 80% 이상")
            if "memory" in selected_items and values["memory_used_percent"] >= 80: warnings.append("메모리 사용률 80% 이상")
            if "disk" in selected_items and values.get("disk_used_percent", 0) >= 80: warnings.append("디스크 사용률 80% 이상")
            for key, label in (("chrony", "Chrony"), ("bonding", "Bonding"), ("mount", "Mount")):
                if key in selected_items and values.get(key) == "warning": warnings.append(f"{label} 상태 확인 필요")
            if "nova_compute" in selected_items and node["role"] == "compute" and values.get("nova_compute") == "warning": warnings.append("nova-compute 비정상")
            for service, label in (("nova", "Nova"), ("neutron", "Neutron"), ("cinder", "Cinder"), ("glance", "Glance"), ("manila", "Manila"), ("octavia", "Octavia"), ("masakari", "Masakari"), ("swift", "Swift"), ("heat", "Heat"), ("system", "System")):
                if values.get(f"{service}_log") == "warning":
                    warnings.append(f"{label} 로그 오류 {values.get(f'{service}_log_count', 0)}건")
            return {**node, "address": address, "reachable": True, "fingerprint": fingerprint, "status": "warning" if warnings else "healthy", "metrics": values, "warnings": warnings}
        except (asyncssh.Error, OSError, RuntimeError) as exc:
            reason = "점검 명령이 120초 안에 완료되지 않음" if isinstance(exc, TimeoutError) else type(exc).__name__
            return {**node, "reachable": False, "status": "warning", "metrics": {}, "warnings": [f"SSH 점검 실패: {reason}"]}

    node_items = selected_items & node_check_keys
    update_progress("nodes", f"전체 노드 {len(nodes)}대의 시스템·서비스·로그를 점검하고 있습니다.", node_items, 20)
    node_results = await asyncio.gather(*(check_node(node) for node in nodes))
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
    controller_command = f"SELECTED_ITEMS={selected_shell}\nMYSQL_DEFAULTS_FILE={shlex.quote(mysql_defaults_path)}\n" + r'''
LC_ALL=C
wanted() { case "$SELECTED_ITEMS" in *"|$1|"*) return 0;; *) return 1;; esac; }
for candidate in /root/contrabass-openrc "$HOME/contrabass-openrc"; do [ -r "$candidate" ] && . "$candidate" >/dev/null 2>&1 && break; done
emit_check() { key="$1"; command="$2"; bad="$3"; wanted "$key" || return; output=$(eval "$command" 2>&1); rc=$?; count=$(printf '%s\n' "$output" | awk 'NF{n++}END{print n+0}'); if [ $rc -ne 0 ]; then state=unavailable; elif [ -n "$bad" ] && printf '%s\n' "$output" | grep -Eiq "$bad"; then state=warning; else state=healthy; fi; encoded=$(printf '%s' "$output" | base64 -w0 2>/dev/null); printf 'check=%s|%s|%s|%s\n' "$key" "$state" "$count" "$encoded"; }
emit_zero_check() { key="$1"; command="$2"; wanted "$key" || return; output=$(eval "$command" 2>&1); rc=$?; value=$(printf '%s\n' "$output" | awk 'NF{v=$NF; if(v !~ /^[0-9]+$/){bad=1} else {seen=1; if(v>max)max=v}}END{if(bad || !seen)print "invalid"; else print max+0}'); if [ $rc -ne 0 ] || [ "$value" = invalid ]; then state=unavailable; value=0; elif [ "$value" -eq 0 ]; then state=healthy; else state=warning; fi; encoded=$(printf '%s' "$output" | base64 -w0 2>/dev/null); printf 'check=%s|%s|%s|%s\n' "$key" "$state" "$value" "$encoded"; }
mysql_query() { if [ -n "$MYSQL_DEFAULTS_FILE" ]; then mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE" "$@"; else mysql "$@"; fi; }
emit_check pcs 'pcs status' 'failed|stopped|offline|unclean'
emit_check vip 'ping -c 2 -W 2 10.255.191.150' '100% packet loss'
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
    options = provider_ssh_options(provider)
    options["known_hosts"] = "/root/.ssh/known_hosts"
    controller_target = provider["controller_hostname"] or provider["vip"]
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
                response = await connection.run(controller_command, check=False, timeout=240)
            finally:
                if sftp and mysql_defaults_path:
                    try:
                        await sftp.remove(mysql_defaults_path)
                    except (asyncssh.SFTPError, OSError):
                        pass
                    sftp.exit()
        for line in response.stdout.splitlines():
            match = re.fullmatch(r"check=([a-z_]+)\|(healthy|warning|unavailable)\|(\d+)\|([A-Za-z0-9+/=]*)", line)
            if match:
                key, item_status, count, encoded = match.groups()
                try: output = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: output = "원본 출력 디코딩 실패"
                is_zero_check = key in {"mysql_host_blocked_errors", "wsrep_local_cert_failures"}
                cluster_items[key] = {
                    "status": item_status,
                    "result": (count if item_status != "unavailable" else "-") if is_zero_check else f"{count}건",
                    "note": ("정상 기준: 0" if is_zero_check else "활성 Controller 기준"),
                    "details": [{"title": provider["controller_hostname"], "output": output or "출력 없음"}],
                }
    except HTTPException:
        raise
    except TimeoutError as exc:
        reason = "활성 Controller 명령 실행 제한시간 초과 (240초)"
        cluster_items = {
            key: {
                "status": "unavailable", "result": "-", "note": reason,
                "details": [{"title": controller_target, "output": "SSH 접속 후 OpenStack 명령 실행이 240초 안에 완료되지 않았습니다."}],
            }
            for key in controller_items
        }
    except (asyncssh.Error, OSError) as exc:
        reason = f"활성 Controller SSH 연결 실패: {type(exc).__name__}"
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
        warning = [node for node in available if node["metrics"].get(key) == "warning" or (isinstance(node["metrics"].get(key), (int, float)) and node["metrics"][key] >= 80)]
        values = [node["metrics"].get(result_key or key) for node in available]
        display = f"최대 {max(value for value in values if isinstance(value, (int, float)))}{suffix}" if any(isinstance(value, (int, float)) for value in values) else f"{len(available)}대 확인"
        raw_key = {"cpu_used_percent": "cpu_raw", "memory_used_percent": "memory_raw", "disk_used_percent": "disk_raw"}.get(key, f"{key}_raw")
        details = [{"title": node["hostname"], "output": node["metrics"].get(raw_key) or str(node["metrics"].get(result_key or key, "확인 불가"))} for node in targets]
        return {"status": "warning" if warning else "healthy", "result": display, "note": f"{len(available)}/{len(targets)}대 수집", "details": details}

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
            new_lines = []
            for original, normalized in zip(
                (line.strip() for line in current_output.splitlines() if line.strip()),
                normalized_log_lines(current_output),
            ):
                if new_counter[normalized] > 0:
                    new_lines.append(original)
                    new_counter[normalized] -= 1
            resolved_lines = list((previous_lines - current_lines).elements())
            details.append({
                "hostname": node["hostname"], "role": node["role"], "status": state or "unavailable",
                "count": node["metrics"].get(count_key, 0),
                "note": "SSH 접속 실패" if not node["reachable"] else ("로그 파일 없음" if state == "unavailable" else ""),
                "log_date": node["metrics"].get(f"{service}_log_date", ""),
                "previous_log_date": node["metrics"].get(f"{service}_previous_log_date", ""),
                "previous_count": sum(previous_lines.values()), "new_count": len(new_lines), "resolved_count": len(resolved_lines),
                "output": current_output, "new_output": "\n".join(new_lines),
            })
        available = [detail for detail in details if detail["status"] != "unavailable"]
        total = sum(detail["count"] for detail in available)
        status = "warning" if any(detail["status"] == "warning" for detail in available) else ("healthy" if available else "unavailable")
        affected = [detail["hostname"] for detail in details if detail["status"] == "warning"]
        new_total = sum(detail["new_count"] for detail in available)
        resolved_total = sum(detail["resolved_count"] for detail in available)
        log_date = next((detail["log_date"] for detail in available if detail["log_date"]), "전날")
        note = f"{log_date} 기준 · 신규 {new_total}건 · 해소 {resolved_total}건"
        if affected: note += f" · 오류 노드: {', '.join(affected)}"
        raw_details = []
        for detail in details:
            comparison = detail["new_output"] or "전전날과 다른 신규 오류 없음"
            raw_details.append({"title": f"{detail['hostname']} ({detail['role']}) · 전전날 대비 신규/변경 로그", "output": comparison})
            raw_details.append({"title": f"{detail['hostname']} ({detail['role']}) · {detail['log_date'] or '전날'} 전체 오류", "output": detail["output"] or detail["note"] or "일치하는 오류 로그 없음"})
        return {"status": status, "result": f"전체 {total}건 / 신규 {new_total}건", "note": note, "log_date": log_date, "new_count": new_total, "resolved_count": resolved_total, "nodes": details, "details": raw_details}

    update_progress("aggregating", "노드별 결과를 집계하고 예외 규칙을 적용하고 있습니다.", selected_items, 88)
    items = {
        "cpu": aggregate_node_item("cpu_used_percent", suffix="%"), "memory": aggregate_node_item("memory_used_percent", suffix="%"),
        "disk": aggregate_node_item("disk_used_percent", suffix="%"), "chrony": aggregate_node_item("chrony"),
        "bonding": aggregate_node_item("bonding"), "mount": aggregate_node_item("mount", role="controller"),
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
                    state = "warning" if value >= 80 else "healthy"
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
    result = {"nodes": node_results, "node_summary": node_summary, "items": items, "selected_items": sorted(selected_items), "metrics": first_metrics, "warnings": warnings,
              "started_at": started.isoformat(), "finished_at": finished.isoformat(), "duration_seconds": round((finished - started).total_seconds(), 1), "trigger": trigger}
    check_id = save_check(provider_id, overall_status, result)
    sync_check_alerts(provider_id, check_id, items)
    update_progress("completed", "일일점검이 완료되었습니다.", [], 100, False)
    return {"check_id": check_id, "provider_id": provider_id, "status": overall_status, **result}


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
    return describe_check_schedule(save_check_schedule(provider_id, request.enabled, request.run_time, selected))


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


async def run_scheduled_checks():
    """Fire each enabled schedule once per local day at its configured HH:MM in INSPECTION_TIMEZONE."""
    logger.info("Inspection scheduler started (timezone %s)", schedule_timezone())
    while True:
        try:
            for schedule in due_check_schedules(datetime.now(schedule_timezone())):
                await run_scheduled_check(schedule)
        except Exception:
            logger.exception("Inspection scheduler iteration failed")
        await asyncio.sleep(20)


@app.on_event("startup")
async def start_check_scheduler():
    # Keep a strong reference: the event loop only holds weak references to tasks.
    task = asyncio.create_task(run_scheduled_checks())
    BACKGROUND_TASKS.add(task)
    task.add_done_callback(BACKGROUND_TASKS.discard)


@app.get("/api/providers/{provider_id}/infrastructure/metrics")
async def provider_infrastructure_metrics(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    controllers = [node["hostname"] for node in list_provider_nodes(provider_id) if node["role"] == "controller"]
    if provider["controller_hostname"] and provider["controller_hostname"] not in controllers:
        controllers.insert(0, provider["controller_hostname"])
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
async def providers(): return FileResponse(BASE_DIR / "provider.html", headers={"Cache-Control": "no-store, max-age=0"})

@app.get("/{asset_name}")
async def static_asset(asset_name: str):
    if asset_name not in {"styles.css", "app.js", "provider.js"}:
        raise HTTPException(404)
    return FileResponse(BASE_DIR / asset_name, headers={"Cache-Control": "no-store, max-age=0"})
