import asyncio
import base64
import ipaddress
import re
import shlex
import socket
from pathlib import Path

import asyncssh
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field, model_validator, field_validator
from provider_store import (
    delete_provider, get_provider, latest_check, list_provider_nodes, list_providers,
    save_check, save_provider, save_provider_nodes,
)

BASE_DIR = Path(__file__).resolve().parent
app = FastAPI(title="OKESTRO OpenStack Operations API", version="0.1.0")

CHECK_KEYS = {
    "cpu", "memory", "disk", "chrony", "bonding", "mount", "pcs", "vip", "rabbitmq", "mysql",
    "endpoint", "nova", "neutron", "cinder", "manila", "octavia", "masakari", "swift", "heat", "nova_compute",
    "vm", "network", "volume", "snapshot", "share", "lb", "amphora",
    "nova_log", "neutron_log", "cinder_log", "glance_log", "manila_log", "octavia_log", "system_log",
    "virtualization", "failed_units", "kernel_errors", "nic_state", "ovs_state", "kvm_acceleration",
    "libvirt_state", "instance_storage", "smart_health", "raid_health",
}


class CheckRequest(BaseModel):
    selected_items: list[str] | None = None


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
    options = provider_ssh_options(provider)
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
            fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if fingerprint != provider["fingerprint"]:
                raise HTTPException(409, "SSH 호스트 키 지문이 등록 시점과 다릅니다.")
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


@app.post("/api/providers/{provider_id}/checks")
async def run_provider_check(provider_id: str, request: CheckRequest | None = None):
    provider = get_provider(provider_id)
    if not provider:
        raise HTTPException(404, "등록된 공급자를 찾을 수 없습니다.")
    nodes = list_provider_nodes(provider_id)
    if not nodes:
        raise HTTPException(409, "먼저 클러스터 탐색을 실행하세요.")
    selected_items = set(request.selected_items) if request and request.selected_items is not None else set(CHECK_KEYS)
    invalid_items = selected_items - CHECK_KEYS
    if invalid_items:
        raise HTTPException(400, f"지원하지 않는 점검 항목: {', '.join(sorted(invalid_items))}")
    if not selected_items:
        raise HTTPException(400, "점검할 항목을 하나 이상 선택하세요.")
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
  if [ ! -d "$directory" ] || ! find "$directory" -maxdepth 1 -type f -name '*.log' -print -quit 2>/dev/null | grep -q .; then
    printf '%s_log=unavailable\n%s_log_count=0\n' "$service" "$service"
    return
  fi
  count=$(grep -h -E 'ERROR|CRITICAL|Traceback' "$directory"/*.log 2>/dev/null | tail -n 100 | wc -l)
  sample=$(grep -h -E 'ERROR|CRITICAL|Traceback' "$directory"/*.log 2>/dev/null | tail -n 100 | base64 -w0 2>/dev/null)
  [ "$count" -gt 0 ] && state=warning || state=healthy
  printf '%s_log=%s\n%s_log_count=%s\n%s_log_sample=%s\n' "$service" "$state" "$service" "$count" "$service" "$sample"
}
for service in nova neutron cinder glance manila octavia; do check_service_log "$service"; done
system_files=""
for file in /var/log/syslog /var/log/messages; do [ -f "$file" ] && system_files="$system_files $file"; done
if [ -z "$system_files" ]; then
  echo system_log=unavailable
  echo system_log_count=0
else
  count=$(grep -h -E 'ERROR|CRITICAL|Traceback' $system_files 2>/dev/null | tail -n 100 | wc -l)
  sample=$(grep -h -E 'ERROR|CRITICAL|Traceback' $system_files 2>/dev/null | tail -n 100 | base64 -w0 2>/dev/null)
  [ "$count" -gt 0 ] && state=warning || state=healthy
  printf 'system_log=%s\nsystem_log_count=%s\nsystem_log_sample=%s\n' "$state" "$count" "$sample"
fi
'''

    async def check_node(node: dict) -> dict:
        options = provider_ssh_options(provider)
        options["known_hosts"] = "/root/.ssh/known_hosts"
        try:
            address = await asyncio.to_thread(socket.gethostbyname, node["hostname"])
            async with asyncssh.connect(address, **options) as connection:
                response = await connection.run(node_command, check=False, timeout=25)
                fingerprint = connection.get_server_host_key().get_fingerprint("sha256")
            if response.exit_status != 0:
                raise RuntimeError("점검 명령 실패")
            values = {}
            for line in response.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    values[key] = value
            integer_keys = {"uptime_seconds", "cpu_cores", "memory_total_kb", "memory_used_kb", "disk_total_kb", "disk_used_kb", "disk_used_percent"}
            integer_keys.update(f"{service}_log_count" for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "system"))
            for key in integer_keys:
                try: values[key] = int(values[key])
                except (KeyError, ValueError): pass
            try: values["cpu_used_percent"] = float(values["cpu_used_percent"])
            except (KeyError, ValueError): values["cpu_used_percent"] = None
            values["memory_used_percent"] = round(values.get("memory_used_kb", 0) / max(values.get("memory_total_kb", 1), 1) * 100, 1)
            for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "system"):
                encoded = values.pop(f"{service}_log_sample", "")
                try: values[f"{service}_log_sample"] = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: values[f"{service}_log_sample"] = ""
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
            for service, label in (("nova", "Nova"), ("neutron", "Neutron"), ("cinder", "Cinder"), ("glance", "Glance"), ("manila", "Manila"), ("octavia", "Octavia"), ("system", "System")):
                if values.get(f"{service}_log") == "warning":
                    warnings.append(f"{label} 로그 오류 {values.get(f'{service}_log_count', 0)}건")
            return {**node, "address": address, "reachable": True, "fingerprint": fingerprint, "status": "warning" if warnings else "healthy", "metrics": values, "warnings": warnings}
        except (asyncssh.Error, OSError, RuntimeError) as exc:
            return {**node, "reachable": False, "status": "warning", "metrics": {}, "warnings": [f"SSH 점검 실패: {type(exc).__name__}"]}

    node_results = await asyncio.gather(*(check_node(node) for node in nodes))

    controller_command = f"SELECTED_ITEMS={selected_shell}\n" + r'''
LC_ALL=C
wanted() { case "$SELECTED_ITEMS" in *"|$1|"*) return 0;; *) return 1;; esac; }
for candidate in /root/contrabass-openrc "$HOME/contrabass-openrc"; do [ -r "$candidate" ] && . "$candidate" >/dev/null 2>&1 && break; done
emit_check() { key="$1"; command="$2"; bad="$3"; wanted "$key" || return; output=$(eval "$command" 2>&1); rc=$?; count=$(printf '%s\n' "$output" | awk 'NF{n++}END{print n+0}'); if [ $rc -ne 0 ]; then state=unavailable; elif [ -n "$bad" ] && printf '%s\n' "$output" | grep -Eiq "$bad"; then state=warning; else state=healthy; fi; encoded=$(printf '%s' "$output" | base64 -w0 2>/dev/null); printf 'check=%s|%s|%s|%s\n' "$key" "$state" "$count" "$encoded"; }
emit_check pcs 'pcs status' 'failed|stopped|offline|unclean'
emit_check vip 'ping -c 2 -W 2 10.255.191.150' '100% packet loss'
emit_check rabbitmq 'rabbitmqctl cluster_status' 'error|failed'
emit_check mysql 'mysql -NBe "show status like '\''wsrep_cluster_weight'\''"' '^$'
emit_check endpoint 'openstack endpoint list -f value' ''
emit_check nova 'openstack compute service list -f value' ' down | disabled '
emit_check neutron 'openstack network agent list -f value' ' down | xxx '
emit_check cinder 'openstack volume service list -f value' ' down | disabled '
emit_check manila 'openstack share service list -f value' ' down | disabled '
emit_check octavia 'openstack loadbalancer list -f value' 'error'
emit_check masakari 'openstack segment list -f value || openstack service list -f value | grep -Ei "masakari|instance-ha"' 'error|failed'
emit_check swift 'openstack object store account show -f value || openstack service list -f value | grep -Ei "swift|object-store"' 'error|failed'
emit_check heat 'openstack orchestration service list -f value || openstack service list -f value | grep -Ei "heat|orchestration"' 'down|disabled|failed'
emit_check vm 'openstack server list --all-projects -f value' ' error '
emit_check network 'openstack network agent list -f value' ' down '
emit_check volume 'openstack volume list --all-projects -f value' ' error '
emit_check snapshot 'openstack volume snapshot list --all-projects -f value' 'creating|error'
emit_check share 'openstack share list --all-projects -f value' 'creating|error'
emit_check lb 'openstack loadbalancer list -f value' 'error'
emit_check amphora 'openstack loadbalancer amphora list -f value' 'error'
exit 0
'''
    cluster_items = {}
    options = provider_ssh_options(provider)
    try:
        async with asyncssh.connect(provider["vip"], **options) as connection:
            if connection.get_server_host_key().get_fingerprint("sha256") != provider["fingerprint"]:
                raise HTTPException(409, "SSH 호스트 키 지문이 등록 시점과 다릅니다.")
            response = await connection.run(controller_command, check=False, timeout=90)
        for line in response.stdout.splitlines():
            match = re.fullmatch(r"check=([a-z_]+)\|(healthy|warning|unavailable)\|(\d+)\|([A-Za-z0-9+/=]*)", line)
            if match:
                key, item_status, count, encoded = match.groups()
                try: output = base64.b64decode(encoded).decode("utf-8", errors="replace")
                except ValueError: output = "원본 출력 디코딩 실패"
                cluster_items[key] = {"status": item_status, "result": f"{count}건", "note": "활성 Controller 기준", "details": [{"title": provider["controller_hostname"], "output": output or "출력 없음"}]}
    except HTTPException:
        raise
    except (asyncssh.Error, OSError):
        cluster_items = {}

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
        for node in node_results:
            state = node["metrics"].get(state_key) if node["reachable"] else "unavailable"
            details.append({
                "hostname": node["hostname"], "role": node["role"], "status": state or "unavailable",
                "count": node["metrics"].get(count_key, 0),
                "note": "SSH 접속 실패" if not node["reachable"] else ("로그 파일 없음" if state == "unavailable" else ""),
                "output": node["metrics"].get(f"{service}_log_sample", ""),
            })
        available = [detail for detail in details if detail["status"] != "unavailable"]
        total = sum(detail["count"] for detail in available)
        status = "warning" if any(detail["status"] == "warning" for detail in available) else ("healthy" if available else "unavailable")
        affected = [detail["hostname"] for detail in details if detail["status"] == "warning"]
        note = f"전체 노드 {len(available)}/{len(details)}대 로그 확인"
        if affected: note += f" · 이상: {', '.join(affected)}"
        raw_details = [{"title": f"{detail['hostname']} ({detail['role']})", "output": detail["output"] or detail["note"] or "일치하는 오류 로그 없음"} for detail in details]
        return {"status": status, "result": f"{total}건", "note": note, "nodes": details, "details": raw_details}

    items = {
        "cpu": aggregate_node_item("cpu_used_percent", suffix="%"), "memory": aggregate_node_item("memory_used_percent", suffix="%"),
        "disk": aggregate_node_item("disk_used_percent", suffix="%"), "chrony": aggregate_node_item("chrony"),
        "bonding": aggregate_node_item("bonding"), "mount": aggregate_node_item("mount", role="controller"),
        "nova_compute": aggregate_node_item("nova_compute", role="compute"), **cluster_items,
        "virtualization": aggregate_node_item("virtualization"), "failed_units": aggregate_node_item("failed_units"),
        "kernel_errors": aggregate_node_item("kernel_errors"), "nic_state": aggregate_node_item("nic_state"),
        "ovs_state": aggregate_node_item("ovs_state"), "kvm_acceleration": aggregate_node_item("kvm_acceleration", role="compute"),
        "libvirt_state": aggregate_node_item("libvirt_state", role="compute"), "instance_storage": aggregate_node_item("instance_storage", role="compute"),
        "smart_health": aggregate_node_item("smart_health"), "raid_health": aggregate_node_item("raid_health"),
    }
    for service in ("nova", "neutron", "cinder", "glance", "manila", "octavia", "system"):
        items[f"{service}_log"] = aggregate_log_item(service)
    items = {key: value for key, value in items.items() if key in selected_items}
    warnings = [f"{node['hostname']}: {warning}" for node in node_results for warning in node["warnings"]]
    warnings.extend(f"{key}: 확인 필요" for key, item in items.items() if item["status"] == "warning")
    overall_status = "warning" if warnings or any(not node["reachable"] for node in node_results) else "healthy"
    first_metrics = next((node["metrics"] for node in node_results if node["reachable"]), {})
    result = {"nodes": node_results, "items": items, "selected_items": sorted(selected_items), "metrics": first_metrics, "warnings": warnings}
    check_id = save_check(provider_id, overall_status, result)
    return {"check_id": check_id, "provider_id": provider_id, "status": overall_status, **result}


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
