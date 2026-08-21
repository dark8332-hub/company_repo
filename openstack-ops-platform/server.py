import ipaddress
import re
from pathlib import Path

import asyncssh
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field, model_validator, field_validator
from provider_store import delete_provider, get_provider, latest_check, list_providers, save_check, save_provider

BASE_DIR = Path(__file__).resolve().parent
app = FastAPI(title="OKESTRO OpenStack Operations API", version="0.1.0")


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


@app.post("/api/providers/connect")
async def connect_provider(request: DiscoveryRequest):
    private_key = None
    if request.auth_method == "private_key":
        try:
            private_key = asyncssh.import_private_key(request.private_key, request.passphrase)
        except (asyncssh.KeyImportError, asyncssh.KeyEncryptionError) as exc:
            raise HTTPException(400, "개인키 형식 또는 암호를 확인하세요.") from exc
    connect_options = {
        "port": request.port, "username": request.username, "known_hosts": None,
        "login_timeout": 10,
    }
    if request.auth_method == "private_key":
        connect_options.update(client_keys=[private_key], password=None)
    else:
        connect_options.update(client_keys=None, password=request.password, preferred_auth="password,keyboard-interactive")
    try:
        async with asyncssh.connect(request.vip, **connect_options) as connection:
            fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if not request.trusted_fingerprint:
                return {"status": "confirmation_required", "fingerprint": fingerprint, "message": "SSH 서버 호스트 키 지문을 확인해 주세요."}
            if request.trusted_fingerprint != fingerprint:
                raise HTTPException(409, "SSH 서버 호스트 키 지문이 변경되었습니다.")
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
        provider["latest_check"] = latest_check(provider["id"])
    return {"providers": providers}


@app.delete("/api/providers/{provider_id}")
async def remove_provider(provider_id: str):
    if not delete_provider(provider_id):
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    return {"status": "deleted", "provider_id": provider_id}


@app.post("/api/providers/{provider_id}/checks")
async def run_provider_check(provider_id: str):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    credentials = provider.pop("credentials")
    options = {"port": provider["port"], "username": provider["username"], "known_hosts": None, "login_timeout": 10}
    if provider["auth_method"] == "private_key":
        try:
            key = asyncssh.import_private_key(credentials["private_key"], credentials.get("passphrase"))
        except (asyncssh.KeyImportError, asyncssh.KeyEncryptionError) as exc:
            raise HTTPException(500, "저장된 SSH 개인키를 사용할 수 없습니다.") from exc
        options.update(client_keys=[key], password=None)
    else:
        options.update(client_keys=None, password=credentials.get("password"), preferred_auth="password,keyboard-interactive")
    command = (
        "LC_ALL=C; printf 'hostname='; hostname; printf 'uptime_seconds='; cut -d. -f1 /proc/uptime; "
        "printf 'cpu_cores='; getconf _NPROCESSORS_ONLN; "
        "awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2}END{printf \"memory_total_kb=%s\\nmemory_used_kb=%s\\n\",t,t-a}' /proc/meminfo; "
        "df -Pk / | awk 'NR==2{printf \"disk_total_kb=%s\\ndisk_used_kb=%s\\ndisk_used_percent=%s\\n\",$2,$3,$5}'"
    )
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if fingerprint != provider["fingerprint"]:
                raise HTTPException(409, "SSH 호스트 키 지문이 등록 시점과 다릅니다.")
            response = await connection.run(command, check=False, timeout=15)
            if response.exit_status != 0:
                raise HTTPException(502, "노드 자원 점검 명령 실행에 실패했습니다.")
    except HTTPException:
        raise
    except (asyncssh.Error, OSError) as exc:
        raise HTTPException(502, f"공급자 점검 연결에 실패했습니다: {type(exc).__name__}") from exc
    metrics = {}
    for line in response.stdout.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            metrics[key] = value.rstrip("%")
    numeric = {"uptime_seconds", "cpu_cores", "memory_total_kb", "memory_used_kb", "disk_total_kb", "disk_used_kb", "disk_used_percent"}
    for key in numeric:
        if key in metrics:
            try: metrics[key] = int(metrics[key])
            except ValueError: pass
    memory_percent = round(metrics.get("memory_used_kb", 0) / max(metrics.get("memory_total_kb", 1), 1) * 100, 1)
    metrics["memory_used_percent"] = memory_percent
    warnings = []
    if memory_percent >= 80: warnings.append("메모리 사용률이 80% 이상입니다.")
    if metrics.get("disk_used_percent", 0) >= 80: warnings.append("루트 디스크 사용률이 80% 이상입니다.")
    status = "warning" if warnings else "healthy"
    check_id = save_check(provider_id, status, {"metrics": metrics, "warnings": warnings})
    return {"check_id": check_id, "provider_id": provider_id, "status": status, "metrics": metrics, "warnings": warnings}


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
async def dashboard(): return FileResponse(BASE_DIR / "index.html")

@app.get("/providers")
async def providers(): return FileResponse(BASE_DIR / "provider.html")

@app.get("/{asset_name}")
async def static_asset(asset_name: str):
    if asset_name not in {"styles.css", "app.js", "provider.js"}:
        raise HTTPException(404)
    return FileResponse(BASE_DIR / asset_name)
