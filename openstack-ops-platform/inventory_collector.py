"""Read-only inventory collection: the bash scripts sent to each node / the active controller and
the pure parsers that turn their output into the inventory payload stored in provider_inventory.

The SSH driver lives in server.py (execute_inventory_collection); nothing in this module talks
to the network, so every parser can be unit-tested with captured command output.

Script output protocol: one line per command,
    section=<name>|<exit code>|<base64 of combined stdout+stderr>
Every child command runs under `timeout -k 5` with stdin redirected from /dev/null (the script
itself arrives on stdin through `bash -s`, so a child that reads stdin would swallow the rest).
"""
from __future__ import annotations

import base64
import json
import re
import shlex

INFRA_SERVICE_PATTERN = "nova|neutron|cinder|glance|keystone|placement|heat|octavia|manila|masakari|swift|rabbitmq|mariadb|mysql|memcached|haproxy|pacemaker|corosync|libvirt|openvswitch|ovn|ceph|nfs|chrony|prometheus|node_exporter"
GLANCE_IMAGE_PATH = "/var/lib/glance/images"
CINDER_MOUNT_PATH = "/var/lib/cinder/mnt"
MAX_SERVERS = 2000
MAX_PLACEMENT_PROVIDERS = 60   # root resource providers whose inventory/usage we read
MAX_QUOTA_PROJECTS = 40        # projects whose compute/volume/network quota we read
MAX_HEADROOM_FLAVORS = 8       # flavors shown in the "how many more fit" table

# Overcommit is expressed per resource class. Each entry is (our key, placement resource class,
# nova.conf allocation-ratio option, nova.conf reserved option, reserved unit conversion to our unit).
RESOURCE_CLASSES = (
    ("vcpu", "VCPU", "cpu_allocation_ratio", "reserved_host_cpus", 1),
    ("memory", "MEMORY_MB", "ram_allocation_ratio", "reserved_host_memory_mb", 1),
    ("disk", "DISK_GB", "disk_allocation_ratio", "reserved_host_disk_mb", 1 / 1024),
)
# nova's defaults when nothing is configured (initial_*_allocation_ratio).
DEFAULT_ALLOCATION_RATIOS = {"vcpu": 16.0, "memory": 1.5, "disk": 1.0}

SCRIPT_PRELUDE = r'''
LC_ALL=C
export LC_ALL
# stdin carries this script (bash -s); every child gets </dev/null so it can never consume it.
run() { name="$1"; shift; out=$(timeout -k 5 "$T_CMD" bash -c "$*" </dev/null 2>&1); rc=$?; printf 'section=%s|%s|%s\n' "$name" "$rc" "$(printf '%s' "$out" | base64 -w0 2>/dev/null || printf '%s' "$out" | base64 | tr -d '\n')"; }
'''

NODE_SCRIPT = SCRIPT_PRELUDE + r'''
run hostname 'hostname -s'
run os 'cat /etc/os-release'
run kernel 'uname -r'
run lscpu 'lscpu'
run meminfo 'grep -E "^(MemTotal|SwapTotal):" /proc/meminfo'
run lsblk 'lsblk -b -P -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,ROTA'
run df 'df -PB1 -x tmpfs -x devtmpfs -x overlay -x squashfs -x efivarfs'
run ip_link 'ip -br link'
run ip_addr 'ip -br addr'
run bonding 'for f in /proc/net/bonding/*; do [ -r "$f" ] || continue; echo "=== $(basename "$f")"; cat "$f"; done'
run services 'systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk "{print \$1}" | grep -E "''' + INFRA_SERVICE_PATTERN + r'''" | sort'
run uptime 'cat /proc/uptime'
run virsh 'if command -v virsh >/dev/null 2>&1; then virsh list --all; else echo "virsh not installed"; exit 90; fi'
run nova_conf 'found=0; for f in /etc/nova/nova.conf /etc/nova/nova.conf.d/*.conf /etc/kolla/nova-compute/nova.conf /etc/kolla/nova-compute/nova.conf.d/*.conf; do [ -r "$f" ] || continue; found=1; echo "=== $f"; grep -E "^[[:space:]]*(initial_)?(cpu|ram|disk)_allocation_ratio|^[[:space:]]*reserved_host_(memory_mb|disk_mb|cpus)" "$f"; done; [ "$found" = 1 ] || { echo "nova.conf 없음"; exit 90; }'
exit 0
'''

CONTROLLER_SCRIPT = SCRIPT_PRELUDE + r'''
for candidate in /root/contrabass-openrc "$HOME/contrabass-openrc" "$HOME/admin-openrc.sh" /etc/kolla/admin-openrc.sh /root/admin-openrc.sh /root/keystonerc_admin; do
  if [ -r "$candidate" ]; then . "$candidate" >/dev/null 2>&1 && { OPENRC_FILE="$candidate"; break; }; fi
done
export OPENRC_FILE
run hostname 'hostname -s'
run openrc 'if [ -n "$OPENRC_FILE" ]; then echo "$OPENRC_FILE"; else echo "OpenRC 파일을 찾을 수 없습니다"; exit 78; fi'
run hypervisors 'openstack hypervisor list --long -f json'
run hypervisor_stats 'openstack hypervisor stats show -f json'
# servers/projects are also reused below to choose which projects to read quota for, so they are
# captured into variables and replayed through run() with their original exit code.
SERVERS_JSON=$(timeout -k 5 "$T_CMD" openstack server list --all-projects --long --limit ''' + str(MAX_SERVERS) + r''' -f json </dev/null 2>&1); SERVERS_RC=$?
export SERVERS_JSON
run servers 'printf "%s" "$SERVERS_JSON"; exit '"$SERVERS_RC"
run volumes 'openstack volume list --all-projects --long -f json'
run networks 'openstack network list --long -f json'
PROJECTS_JSON=$(timeout -k 5 "$T_CMD" openstack project list -f json </dev/null 2>&1); PROJECTS_RC=$?
export PROJECTS_JSON
run projects 'printf "%s" "$PROJECTS_JSON"; exit '"$PROJECTS_RC"
run flavors 'openstack flavor list --all -f json'
run aggregates 'openstack aggregate list --long -f json'
run ceph 'if command -v ceph >/dev/null 2>&1; then timeout -k 5 20 ceph -s -f json </dev/null; else echo "ceph not installed"; exit 90; fi'
run mounts 'awk "\$3 ~ /^nfs/ {print}" /proc/mounts'
run df_nfs 'df -PB1 -t nfs -t nfs4 2>/dev/null || true'
run cinder_mounts 'ls -1 ''' + CINDER_MOUNT_PATH + r''' 2>/dev/null || true'
for name in $(openstack hypervisor list -f value -c "Hypervisor Hostname" 2>/dev/null </dev/null | head -n 30); do
  run "hypervisor_show|$name" "openstack hypervisor show -f json $(printf '%q' "$name")"
done

# --- Placement overcommit and per-project quota, read over the REST APIs ---------------------
# One `openstack` CLI call costs seconds; these need one request per resource provider and per
# project, so they go through curl with a scoped token. The token is kept in the environment and
# is never written to a section (sections are stored in the DB and shown in the browser).
TOKEN_JSON=$(timeout -k 5 "$T_CMD" openstack token issue -f json </dev/null 2>/dev/null)
OS_TOKEN=$(printf '%s' "$TOKEN_JSON" | python3 -c 'import json,sys
try: print((json.load(sys.stdin) or {}).get("id") or "")
except Exception: print("")' 2>/dev/null)
OS_PROJECT=$(printf '%s' "$TOKEN_JSON" | python3 -c 'import json,sys
try: print((json.load(sys.stdin) or {}).get("project_id") or "")
except Exception: print("")' 2>/dev/null)
TOKEN_JSON=""
ENDPOINTS_JSON=$(timeout -k 5 "$T_CMD" openstack endpoint list -f json </dev/null 2>/dev/null)
export OS_TOKEN OS_PROJECT ENDPOINTS_JSON

pick_url() {
  printf '%s' "$ENDPOINTS_JSON" | python3 -c 'import json,os,sys
want=sys.argv[1]
try: rows=json.load(sys.stdin)
except Exception: rows=[]
found={}
for row in rows if isinstance(rows,list) else []:
    if not isinstance(row,dict): continue
    low={str(k).lower().replace("_"," "):v for k,v in row.items()}
    if str(low.get("service type") or "")!=want: continue
    if str(low.get("enabled","True")).lower()=="false": continue
    found.setdefault(str(low.get("interface") or ""),str(low.get("url") or ""))
url=found.get("internal") or found.get("public") or found.get("admin") or ""
pid=os.environ.get("OS_PROJECT") or ""
print(url.replace("%(tenant_id)s",pid).replace("%(project_id)s",pid).rstrip("/"))' "$1" 2>/dev/null
}
api() { curl -sS -k --max-time 12 -H "X-Auth-Token: $OS_TOKEN" -H "Accept: application/json" "$1" 2>&1; }
papi() { curl -sS -k --max-time 12 -H "X-Auth-Token: $OS_TOKEN" -H "Accept: application/json" -H "OpenStack-API-Version: placement 1.29" "$1" 2>&1; }
export -f api papi

PLACEMENT_URL=$(pick_url placement)
COMPUTE_URL=$(pick_url compute)
VOLUME_URL=$(pick_url volumev3)
[ -n "$VOLUME_URL" ] || VOLUME_URL=$(pick_url block-storage)
NETWORK_URL=$(pick_url network)
export PLACEMENT_URL COMPUTE_URL VOLUME_URL NETWORK_URL

if [ -z "$OS_TOKEN" ]; then
  run api_access 'echo "인증 토큰을 발급하지 못해 오버커밋·쿼터를 수집하지 못했습니다"; exit 77'
elif ! command -v curl >/dev/null 2>&1; then
  run api_access 'echo "활성 Controller에 curl이 없어 오버커밋·쿼터를 수집하지 못했습니다"; exit 78'
else
  run api_access 'echo "placement=${PLACEMENT_URL:-none} compute=${COMPUTE_URL:-none} volume=${VOLUME_URL:-none} network=${NETWORK_URL:-none}"'
  if [ -n "$PLACEMENT_URL" ]; then
    RP_JSON=$(papi "$PLACEMENT_URL/resource_providers")
    export RP_JSON
    run placement_providers 'printf "%s" "$RP_JSON"'
    for uuid in $(printf '%s' "$RP_JSON" | python3 -c 'import json,sys
try: data=json.load(sys.stdin)
except Exception: data={}
rows=(data or {}).get("resource_providers") or []
out=[str(r.get("uuid") or "") for r in rows if isinstance(r,dict) and not r.get("parent_provider_uuid")]
print("\n".join(x for x in out if x))' 2>/dev/null | head -n ''' + str(MAX_PLACEMENT_PROVIDERS) + r'''); do
      run "placement_inv|$uuid" "papi \"\$PLACEMENT_URL/resource_providers/$uuid/inventories\""
      run "placement_use|$uuid" "papi \"\$PLACEMENT_URL/resource_providers/$uuid/usages\""
    done
  fi
  for pid in $(python3 -c 'import json,os
def rows(name):
    try: data=json.loads(os.environ.get(name) or "")
    except Exception: return []
    return data if isinstance(data,list) else []
def pick(row,*names):
    low={str(k).lower().replace("_"," "):v for k,v in row.items()}
    for n in names:
        value=low.get(n.lower().replace("_"," "))
        if value: return str(value)
    return ""
counts={}
for server in rows("SERVERS_JSON"):
    pid=pick(server,"Project ID","project_id","tenant_id")
    if pid: counts[pid]=counts.get(pid,0)+1
ids=[pick(project,"ID","id") for project in rows("PROJECTS_JSON")]
ids=[pid for pid in ids if pid]
ids.sort(key=lambda pid:(-counts.get(pid,0),pid))
print("\n".join(ids))' 2>/dev/null | head -n ''' + str(MAX_QUOTA_PROJECTS) + r'''); do
    [ -n "$COMPUTE_URL" ] && run "quota_compute|$pid" "api \"\$COMPUTE_URL/os-quota-sets/$pid/detail\""
    [ -n "$VOLUME_URL" ] && run "quota_volume|$pid" "api \"\$VOLUME_URL/os-quota-sets/$pid?usage=True\""
    [ -n "$NETWORK_URL" ] && run "quota_network|$pid" "api \"\$NETWORK_URL/v2.0/quotas/$pid/details.json\""
  done
fi
exit 0
'''


# --- protocol -----------------------------------------------------------------------------------

def parse_sections(stdout: str) -> dict[str, dict]:
    """`section=name|rc|base64` lines → {name: {"rc": int, "output": str}} (unknown lines ignored)."""
    sections: dict[str, dict] = {}
    for line in stdout.splitlines():
        match = re.fullmatch(r"section=([^|]+(?:\|[^|]*)?)\|(-?\d+)\|([A-Za-z0-9+/=]*)", line.strip())
        if not match:
            continue
        name, rc, encoded = match.groups()
        try:
            output = base64.b64decode(encoded).decode("utf-8", errors="replace")
        except (ValueError, TypeError):
            output = ""
        sections[name] = {"rc": int(rc), "output": output}
    return sections


def _section(sections: dict, name: str) -> tuple[int, str]:
    entry = sections.get(name) or {}
    return int(entry.get("rc", 1)), str(entry.get("output", ""))


def _json_section(sections: dict, name: str):
    rc, output = _section(sections, name)
    if rc != 0:
        return None, output.strip()[:500] or f"exit {rc}"
    try:
        return json.loads(output), ""
    except ValueError:
        return None, "JSON 해석 실패"


def _int(value, default=0) -> int:
    try:
        return int(float(str(value).strip()))
    except (TypeError, ValueError):
        return default


# --- node parsers --------------------------------------------------------------------------------

def parse_os_release(text: str) -> dict:
    values = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"')
    return {"name": values.get("PRETTY_NAME") or values.get("NAME", ""), "id": values.get("ID", ""), "version": values.get("VERSION_ID", "")}


def parse_lscpu(text: str) -> dict:
    values = {}
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return {
        "model": values.get("Model name", ""), "architecture": values.get("Architecture", ""),
        "cpus": _int(values.get("CPU(s)")), "sockets": _int(values.get("Socket(s)")),
        "cores_per_socket": _int(values.get("Core(s) per socket")), "threads_per_core": _int(values.get("Thread(s) per core")),
        "hypervisor_vendor": values.get("Hypervisor vendor", ""), "virtualization": values.get("Virtualization", ""),
    }


def parse_meminfo(text: str) -> dict:
    values = {}
    for line in text.splitlines():
        match = re.match(r"(\w+):\s+(\d+)", line)
        if match:
            values[match.group(1)] = int(match.group(2))
    return {"memory_total_kb": values.get("MemTotal", 0), "swap_total_kb": values.get("SwapTotal", 0)}


def parse_lsblk(text: str) -> list[dict]:
    disks = []
    for line in text.splitlines():
        pairs = dict(re.findall(r'(\w+)="([^"]*)"', line))
        if not pairs.get("NAME"):
            continue
        disks.append({
            "name": pairs.get("NAME", ""), "size_bytes": _int(pairs.get("SIZE")), "type": pairs.get("TYPE", ""),
            "mountpoint": pairs.get("MOUNTPOINT", ""), "model": pairs.get("MODEL", "").strip(), "rotational": pairs.get("ROTA") == "1",
        })
    return disks


def parse_df(text: str) -> list[dict]:
    filesystems = []
    for line in text.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 6:
            continue
        filesystems.append({
            "filesystem": parts[0], "size_bytes": _int(parts[1]), "used_bytes": _int(parts[2]), "avail_bytes": _int(parts[3]),
            "use_percent": _int(parts[4].rstrip("%")), "mountpoint": " ".join(parts[5:]),
        })
    return filesystems


def parse_ip_brief(link_text: str, addr_text: str) -> list[dict]:
    addresses: dict[str, list[str]] = {}
    for line in addr_text.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            addresses[parts[0].split("@")[0]] = parts[2:]
    interfaces = []
    for line in link_text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        name = parts[0].split("@")[0]
        if name == "lo":
            continue
        interfaces.append({"name": name, "state": parts[1], "mac": parts[2] if len(parts) > 2 else "", "flags": " ".join(parts[3:]), "addresses": addresses.get(name, [])})
    return interfaces


def parse_bonding(text: str) -> list[dict]:
    bonds: list[dict] = []
    current: dict | None = None
    slave: dict | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("=== "):
            current = {"name": line[4:].strip(), "mode": "", "mii_status": "", "active_slave": "", "slaves": []}
            bonds.append(current)
            slave = None
            continue
        if current is None or not line:
            continue
        if line.startswith("Bonding Mode:"):
            current["mode"] = line.split(":", 1)[1].strip()
        elif line.startswith("Currently Active Slave:"):
            current["active_slave"] = line.split(":", 1)[1].strip()
        elif line.startswith("Slave Interface:"):
            slave = {"name": line.split(":", 1)[1].strip(), "mii_status": "", "speed": ""}
            current["slaves"].append(slave)
        elif line.startswith("MII Status:"):
            status = line.split(":", 1)[1].strip()
            if slave is not None:
                slave["mii_status"] = status
            else:
                current["mii_status"] = status
        elif line.startswith("Speed:") and slave is not None:
            slave["speed"] = line.split(":", 1)[1].strip()
    return bonds


def parse_nova_conf(text: str) -> dict:
    """Allocation ratios and reserved-host values from a compute node's nova.conf files.

    nova treats a ratio of 0.0 (or absent) as "use initial_<x>_allocation_ratio", so a configured
    0.0 is not an override and the initial_ value is kept as the effective one. Later files win,
    which matches how nova.conf.d drop-ins override the base file.
    """
    values: dict[str, float] = {}
    initial: dict[str, float] = {}
    files: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("=== "):
            files.append(line[4:].strip())
            continue
        match = re.match(r"(initial_)?(cpu|ram|disk)_allocation_ratio\s*=\s*([0-9.]+)", line)
        if match:
            key = {"cpu": "vcpu", "ram": "memory", "disk": "disk"}[match.group(2)]
            try:
                number = float(match.group(3))
            except ValueError:
                continue
            if match.group(1):
                initial[key] = number
            elif number > 0:
                values[key] = number
            continue
        match = re.match(r"reserved_host_(memory_mb|disk_mb|cpus)\s*=\s*(\d+)", line)
        if match:
            values[f"reserved_{match.group(1)}"] = float(match.group(2))
    ratios = {key: values.get(key, initial.get(key)) for key in ("vcpu", "memory", "disk")}
    return {
        "files": files,
        "ratios": {key: value for key, value in ratios.items() if value},
        "reserved": {"vcpu": int(values.get("reserved_cpus", 0)), "memory": int(values.get("reserved_memory_mb", 0)),
                     "disk": round(values.get("reserved_disk_mb", 0) / 1024, 2)},
    }


def parse_virsh(text: str) -> list[dict]:
    vms = []
    for line in text.splitlines():
        match = re.match(r"\s*(-|\d+)\s+(\S+)\s+(.+?)\s*$", line)
        if match and match.group(2) not in {"Name", "이름"}:
            vms.append({"name": match.group(2), "state": match.group(3).strip()})
    return vms


def parse_node_output(stdout: str) -> dict:
    """The per-node script output → the node's inventory record (without SSH metadata)."""
    sections = parse_sections(stdout)
    rc, os_text = _section(sections, "os")
    _, kernel = _section(sections, "kernel")
    _, lscpu = _section(sections, "lscpu")
    _, meminfo = _section(sections, "meminfo")
    _, lsblk = _section(sections, "lsblk")
    _, df_text = _section(sections, "df")
    _, link_text = _section(sections, "ip_link")
    _, addr_text = _section(sections, "ip_addr")
    _, bonding = _section(sections, "bonding")
    services_rc, services = _section(sections, "services")
    _, uptime = _section(sections, "uptime")
    virsh_rc, virsh = _section(sections, "virsh")
    nova_conf_rc, nova_conf = _section(sections, "nova_conf")
    _, short_hostname = _section(sections, "hostname")
    try:
        uptime_seconds = int(float(uptime.split()[0]))
    except (IndexError, ValueError):
        uptime_seconds = None
    return {
        "reported_hostname": short_hostname.strip(),
        "os": parse_os_release(os_text) if rc == 0 else {"name": "", "id": "", "version": ""},
        "kernel": kernel.strip(),
        "cpu": parse_lscpu(lscpu),
        **parse_meminfo(meminfo),
        "uptime_seconds": uptime_seconds,
        "disks": [disk for disk in parse_lsblk(lsblk) if disk["type"] in {"disk", "raid1", "raid0", "raid5", "raid6", "raid10", "mpath"}],
        "block_devices": parse_lsblk(lsblk),
        "filesystems": parse_df(df_text),
        "interfaces": parse_ip_brief(link_text, addr_text),
        "bonds": parse_bonding(bonding),
        "services": [line.strip() for line in services.splitlines() if line.strip()] if services_rc == 0 else [],
        "vms": parse_virsh(virsh) if virsh_rc == 0 else [],
        "virsh_available": virsh_rc == 0,
        "nova_conf": parse_nova_conf(nova_conf) if nova_conf_rc == 0 else {"files": [], "ratios": {}, "reserved": {}},
        "sections_ok": sum(1 for entry in sections.values() if entry["rc"] == 0),
        "sections_total": len(sections),
    }


# --- controller parsers ---------------------------------------------------------------------------

def _pick(row: dict, *names, default=None):
    """First present key among several naming variants (OSC column names differ across releases)."""
    lowered = {str(key).lower().replace("_", " "): value for key, value in row.items()}
    for name in names:
        value = lowered.get(name.lower().replace("_", " "))
        if value is not None and value != "":
            return value
    return default


def _rows(data) -> list[dict]:
    return [row for row in data if isinstance(row, dict)] if isinstance(data, list) else []


def parse_hypervisors(list_data, show_data: dict[str, dict]) -> list[dict]:
    hypervisors = []
    for row in _rows(list_data):
        hostname = str(_pick(row, "Hypervisor Hostname", "hypervisor_hostname", "name", default=""))
        detail = show_data.get(hostname) or show_data.get(hostname.split(".")[0]) or {}
        merged = {**row, **{key: value for key, value in detail.items() if value not in (None, "")}}
        hypervisors.append({
            "id": str(_pick(row, "ID", "id", default="")),
            "hostname": hostname,
            "type": str(_pick(merged, "Hypervisor Type", "hypervisor_type", default="")),
            "host_ip": str(_pick(merged, "Host IP", "host_ip", default="")),
            "state": str(_pick(merged, "State", "state", default="")),
            "status": str(_pick(merged, "Status", "status", default="")),
            "vcpus": _int(_pick(merged, "vCPUs", "vcpus", default=0)),
            "vcpus_used": _int(_pick(merged, "vCPUs Used", "vcpus_used", default=0)),
            "memory_mb": _int(_pick(merged, "Memory MB", "memory_mb", "memory_size", default=0)),
            "memory_mb_used": _int(_pick(merged, "Memory MB Used", "memory_mb_used", "memory_used", default=0)),
            "local_gb": _int(_pick(merged, "Local GB", "local_gb", "local_disk_size", default=0)),
            "local_gb_used": _int(_pick(merged, "Local GB Used", "local_gb_used", "local_disk_used", default=0)),
            "running_vms": _int(_pick(merged, "Running VMs", "running_vms", default=0)),
        })
    return hypervisors


def parse_flavors(data) -> dict[str, dict]:
    flavors = {}
    for row in _rows(data):
        entry = {"id": str(_pick(row, "ID", "id", default="")), "name": str(_pick(row, "Name", "name", default="")),
                 "vcpus": _int(_pick(row, "VCPUs", "vcpus", default=0)), "ram_mb": _int(_pick(row, "RAM", "ram", default=0)),
                 "disk_gb": _int(_pick(row, "Disk", "disk", default=0)), "ephemeral_gb": _int(_pick(row, "Ephemeral", "ephemeral", default=0))}
        if entry["id"]:
            flavors[entry["id"]] = entry
        if entry["name"]:
            flavors.setdefault(entry["name"], entry)
    return flavors


def parse_servers(data, flavors: dict[str, dict]) -> list[dict]:
    servers = []
    for row in _rows(data)[:MAX_SERVERS]:
        flavor = _pick(row, "Flavor Name", "Flavor", "flavor", default="")
        flavor_id = str(_pick(row, "Flavor ID", "flavor_id", default=""))
        if isinstance(flavor, dict):
            flavor_id = flavor_id or str(flavor.get("id") or "")
            flavor = flavor.get("original_name") or flavor.get("name") or flavor_id
        spec = flavors.get(flavor_id) or flavors.get(str(flavor)) or {}
        networks = _pick(row, "Networks", "networks", default={})
        if isinstance(networks, dict):
            network_text = ", ".join(f"{name}={', '.join(map(str, addresses))}" for name, addresses in networks.items())
        else:
            network_text = str(networks or "")
        servers.append({
            "id": str(_pick(row, "ID", "id", default="")), "name": str(_pick(row, "Name", "name", default="")),
            "status": str(_pick(row, "Status", "status", default="")), "power_state": str(_pick(row, "Power State", "power_state", default="")),
            "host": str(_pick(row, "Host", "host", "OS-EXT-SRV-ATTR:host", default="")),
            "project_id": str(_pick(row, "Project ID", "project_id", "tenant_id", default="")),
            "flavor": str(flavor), "vcpus": spec.get("vcpus", 0), "ram_mb": spec.get("ram_mb", 0), "disk_gb": spec.get("disk_gb", 0),
            "image": str(_pick(row, "Image Name", "Image", "image", default="")), "availability_zone": str(_pick(row, "Availability Zone", "availability_zone", default="")),
            "networks": network_text[:300],
        })
    return servers


def parse_volumes(data) -> list[dict]:
    volumes = []
    for row in _rows(data):
        attached = _pick(row, "Attached to", "attachments", default="")
        if isinstance(attached, list):
            attached = ", ".join(str(item.get("server_id") or item.get("device") or item) if isinstance(item, dict) else str(item) for item in attached)
        volumes.append({"id": str(_pick(row, "ID", "id", default="")), "name": str(_pick(row, "Name", "name", default="")), "status": str(_pick(row, "Status", "status", default="")),
                        "size_gb": _int(_pick(row, "Size", "size", default=0)), "type": str(_pick(row, "Type", "volume_type", default="")), "bootable": str(_pick(row, "Bootable", "bootable", default="")),
                        "attached_to": str(attached)[:200]})
    return volumes


def parse_networks(data) -> list[dict]:
    networks = []
    for row in _rows(data):
        subnets = _pick(row, "Subnets", "subnets", default=[])
        networks.append({"id": str(_pick(row, "ID", "id", default="")), "name": str(_pick(row, "Name", "name", default="")), "status": str(_pick(row, "Status", "status", default="")),
                         "project_id": str(_pick(row, "Project", "project_id", default="")), "external": bool(_pick(row, "Router Type", "router:external", "is_router_external", default=False)),
                         "shared": bool(_pick(row, "Shared", "shared", "is_shared", default=False)), "network_type": str(_pick(row, "Network Type", "provider:network_type", default="")),
                         "subnets": len(subnets) if isinstance(subnets, list) else (len(str(subnets).split(",")) if subnets else 0)})
    return networks


def parse_projects(data) -> dict[str, str]:
    return {str(_pick(row, "ID", "id", default="")): str(_pick(row, "Name", "name", default="")) for row in _rows(data)}


def parse_placement(sections: dict) -> dict:
    """Placement resource providers → per-provider overcommit facts keyed by short hostname.

    Placement is the authority for allocation ratios: nova.conf only seeds them, and an operator
    can change a provider's ratio through the Placement API without touching nova.conf.
    """
    providers, error = _json_section(sections, "placement_providers")
    rows = (providers or {}).get("resource_providers") if isinstance(providers, dict) else None
    by_uuid = {str(row.get("uuid") or ""): str(row.get("name") or "") for row in (rows or []) if isinstance(row, dict)}
    result: dict[str, dict] = {}
    for name, entry in sections.items():
        if not name.startswith("placement_inv|") or entry["rc"] != 0:
            continue
        uuid = name.split("|", 1)[1]
        inventories, _ = _json_section(sections, name)
        usages, _ = _json_section(sections, f"placement_use|{uuid}")
        inventory_map = (inventories or {}).get("inventories") if isinstance(inventories, dict) else None
        usage_map = (usages or {}).get("usages") if isinstance(usages, dict) else None
        if not isinstance(inventory_map, dict):
            continue
        resources = {}
        for key, resource_class, _option, _reserved_option, _unit in RESOURCE_CLASSES:
            item = inventory_map.get(resource_class)
            if not isinstance(item, dict):
                continue
            total = _int(item.get("total"))
            reserved = _int(item.get("reserved"))
            try:
                ratio = float(item.get("allocation_ratio") or 0) or DEFAULT_ALLOCATION_RATIOS[key]
            except (TypeError, ValueError):
                ratio = DEFAULT_ALLOCATION_RATIOS[key]
            resources[key] = {"total": total, "reserved": reserved, "ratio": round(ratio, 3),
                              "used": _int((usage_map or {}).get(resource_class)) if isinstance(usage_map, dict) else 0,
                              "usage_known": isinstance(usage_map, dict) and resource_class in usage_map}
        if not resources:
            continue
        hostname = by_uuid.get(uuid, "")
        result[(hostname or uuid).split(".")[0]] = {"uuid": uuid, "name": hostname, "resources": resources}
    return {"providers": result, "available": bool(result), "error": error if not result else ""}


def _quota_pairs(payload, container: str, mapping: dict[str, str], used_keys: tuple[str, ...]) -> dict[str, dict]:
    """One quota-set response → {our key: {"used": n, "limit": m}}; limit -1/None means unlimited."""
    body = (payload or {}).get(container) if isinstance(payload, dict) else None
    if not isinstance(body, dict):
        return {}
    result = {}
    for source, key in mapping.items():
        item = body.get(source)
        if not isinstance(item, dict):
            continue
        used = next((_int(item[name]) for name in used_keys if name in item), 0)
        limit = item.get("limit")
        result[key] = {"used": used + _int(item.get("reserved")), "limit": _int(limit, -1) if limit is not None else -1}
    return result


def parse_project_quotas(sections: dict) -> dict[str, dict]:
    """Nova/Cinder/Neutron quota-set responses → {project id: {resource: {"used", "limit"}}}."""
    quotas: dict[str, dict] = {}
    specs = (
        ("quota_compute", "quota_set", {"instances": "instances", "cores": "vcpus", "ram": "ram_mb"}, ("in_use",)),
        ("quota_volume", "quota_set", {"volumes": "volumes", "gigabytes": "disk_gb", "snapshots": "snapshots"}, ("in_use",)),
        ("quota_network", "quota", {"floatingip": "floating_ips", "network": "networks", "port": "ports",
                                    "router": "routers", "security_group": "security_groups"}, ("used", "in_use")),
    )
    for name, entry in sections.items():
        prefix, _, project_id = name.partition("|")
        spec = next((item for item in specs if item[0] == prefix), None)
        if not spec or not project_id or entry["rc"] != 0:
            continue
        payload, _ = _json_section(sections, name)
        pairs = _quota_pairs(payload, spec[1], spec[2], spec[3])
        if pairs:
            quotas.setdefault(project_id, {}).update(pairs)
    return quotas


def parse_aggregates(data) -> dict[str, str]:
    """`openstack aggregate list --long` → {short hostname: availability zone}."""
    hosts: dict[str, str] = {}
    for row in _rows(data):
        zone = str(_pick(row, "Availability Zone", "availability_zone", default="") or "")
        members = _pick(row, "Hosts", "hosts", default=[])
        if isinstance(members, str):
            members = [item.strip() for item in re.split(r"[,\s]+", members) if item.strip()]
        for host in members if isinstance(members, list) else []:
            short = str(host).split(".")[0]
            if short and zone:
                hosts[short] = zone
    return hosts


def parse_ceph_status(data) -> dict | None:
    if not isinstance(data, dict):
        return None
    health = data.get("health") or {}
    osdmap = data.get("osdmap") or {}
    osdmap = osdmap.get("osdmap") or osdmap
    pgmap = data.get("pgmap") or {}
    checks = health.get("checks") or {}
    return {
        "health": health.get("status", ""), "fsid": data.get("fsid", ""),
        "osds": _int(osdmap.get("num_osds")), "osds_up": _int(osdmap.get("num_up_osds")), "osds_in": _int(osdmap.get("num_in_osds")),
        "bytes_used": _int(pgmap.get("bytes_used")), "bytes_total": _int(pgmap.get("bytes_total")), "bytes_avail": _int(pgmap.get("bytes_avail")),
        "pgs": _int(pgmap.get("num_pgs")), "pools": _int(pgmap.get("num_pools")),
        "warnings": [f"{name}: {(detail.get('summary') or {}).get('message', '')}" for name, detail in checks.items() if isinstance(detail, dict)][:10],
    }


def parse_nfs_mounts(mounts_text: str, df_text: str, cinder_dirs: str = "") -> dict:
    usage = {fs["mountpoint"]: fs for fs in parse_df(df_text)}
    mounts = []
    for line in mounts_text.splitlines():
        parts = line.split()
        if len(parts) < 3 or not parts[2].startswith("nfs"):
            continue
        entry = {"export": parts[0], "mountpoint": parts[1], "type": parts[2], "options": parts[3] if len(parts) > 3 else ""}
        stats = usage.get(parts[1])
        if stats:
            entry.update({"size_bytes": stats["size_bytes"], "used_bytes": stats["used_bytes"], "avail_bytes": stats["avail_bytes"], "use_percent": stats["use_percent"]})
        # A mount serves a service path when it is that path, a parent of it, or (Cinder mounts each
        # NFS share under its own subdirectory) a child of it.
        mountpoint = parts[1].rstrip("/") or "/"
        entry["serves"] = [label for label, path in (("Glance 이미지", GLANCE_IMAGE_PATH), ("Cinder 볼륨", CINDER_MOUNT_PATH))
                           if path == mountpoint or path.startswith(mountpoint + "/") or mountpoint.startswith(path + "/")]
        mounts.append(entry)
    return {
        "mounts": mounts,
        "glance_on_nfs": any("Glance 이미지" in mount["serves"] for mount in mounts),
        "cinder_on_nfs": any("Cinder 볼륨" in mount["serves"] for mount in mounts),
        "cinder_mount_dirs": [line.strip() for line in cinder_dirs.splitlines() if line.strip()],
    }


def parse_controller_output(stdout: str) -> dict:
    """The active-controller script output → openstack inventory, capacity and storage sections."""
    sections = parse_sections(stdout)
    openrc_rc, openrc = _section(sections, "openrc")
    hypervisor_list, hv_error = _json_section(sections, "hypervisors")
    stats, _ = _json_section(sections, "hypervisor_stats")
    server_list, server_error = _json_section(sections, "servers")
    volume_list, volume_error = _json_section(sections, "volumes")
    network_list, network_error = _json_section(sections, "networks")
    project_list, _ = _json_section(sections, "projects")
    flavor_list, _ = _json_section(sections, "flavors")
    show_data = {}
    for name, entry in sections.items():
        if name.startswith("hypervisor_show|") and entry["rc"] == 0:
            try:
                show_data[name.split("|", 1)[1]] = json.loads(entry["output"])
            except ValueError:
                pass
    flavors = parse_flavors(flavor_list)
    hypervisors = parse_hypervisors(hypervisor_list, show_data)
    servers = parse_servers(server_list, flavors)
    projects = parse_projects(project_list)
    placement = parse_placement(sections)
    quotas = parse_project_quotas(sections)
    aggregate_list, _ = _json_section(sections, "aggregates")
    api_rc, api_message = _section(sections, "api_access")
    ceph_data, _ = _json_section(sections, "ceph")
    _, mounts_text = _section(sections, "mounts")
    _, df_nfs = _section(sections, "df_nfs")
    _, cinder_dirs = _section(sections, "cinder_mounts")
    openstack = {
        "available": openrc_rc == 0 and hypervisor_list is not None,
        "openrc": openrc.strip() if openrc_rc == 0 else "",
        "errors": {key: value for key, value in (("openrc", "" if openrc_rc == 0 else openrc.strip()), ("hypervisors", hv_error), ("servers", server_error), ("volumes", volume_error), ("networks", network_error)) if value},
        "hypervisors": hypervisors,
        "hypervisor_stats": stats if isinstance(stats, dict) else None,
        "servers": servers, "volumes": parse_volumes(volume_list), "networks": parse_networks(network_list),
        "projects": [{"id": key, "name": value} for key, value in projects.items()],
        "flavors": sorted({id(value): value for value in flavors.values()}.values(), key=lambda flavor: flavor["name"]),
    }
    flavor_specs = sorted({id(value): value for value in flavors.values()}.values(), key=lambda flavor: flavor["name"])
    return {
        "openstack": openstack,
        "capacity": build_capacity(hypervisors, servers, projects, placement, quotas, parse_aggregates(aggregate_list), flavor_specs),
        "storage": build_storage(parse_ceph_status(ceph_data), parse_nfs_mounts(mounts_text, df_nfs, cinder_dirs)),
        "api_access": {"ok": api_rc == 0, "message": api_message.strip()[:300],
                       "placement": placement["available"], "quota_projects": len(quotas)},
    }


def _percent(used: float, total: float) -> float | None:
    return round(used / total * 100, 1) if total else None


def _capacity_entry(total: int, reserved: int, ratio: float, used: int) -> dict:
    """One resource on one hypervisor: physical total vs. the capacity overcommit actually allows.

    nova schedules against (total - reserved) * allocation_ratio, so that product - not the physical
    total - is what "full" means. `free` is what is left for new instances.
    """
    capacity = int(max(0, total - reserved) * ratio)
    return {"total": total, "reserved": reserved, "ratio": round(ratio, 3), "capacity": capacity, "used": used,
            "percent": _percent(used, capacity), "physical_percent": _percent(used, total), "free": max(0, capacity - used)}


def _allocation_for(row: dict, placement_entry: dict | None, node_conf: dict | None) -> dict:
    """Overcommit facts for one hypervisor, preferring Placement over the node's nova.conf."""
    physical = {"vcpu": (row["vcpus"], row["vcpus_used"]), "memory": (row["memory_mb"], row["memory_mb_used"]), "disk": (row["local_gb"], row["local_gb_used"])}
    if placement_entry:
        detail = {}
        for key, (total, used) in physical.items():
            item = (placement_entry.get("resources") or {}).get(key)
            if not item:
                continue
            detail[key] = _capacity_entry(item["total"] or total, item["reserved"], item["ratio"], item["used"] if item["usage_known"] else used)
        if detail:
            return {"source": "placement", **detail}
    ratios = (node_conf or {}).get("ratios") or {}
    if ratios:
        reserved = (node_conf or {}).get("reserved") or {}
        detail = {}
        for key, (total, used) in physical.items():
            if not ratios.get(key):
                continue
            detail[key] = _capacity_entry(total, int(reserved.get(key) or 0), float(ratios[key]), used)
        if detail:
            return {"source": "nova.conf", **detail}
    return {"source": ""}


def _schedulable(row: dict) -> bool:
    """Only an up + enabled hypervisor can take new instances, so only it counts toward headroom."""
    return str(row.get("state", "")).lower() == "up" and str(row.get("status", "enabled")).lower() != "disabled"


def _headroom(hypervisors: list[dict], flavors: list[dict]) -> list[dict]:
    """How many more instances of each flavor still fit, and which resource runs out first."""
    results = []
    for flavor in flavors:
        demand = {"vcpu": flavor.get("vcpus") or 0, "memory": flavor.get("ram_mb") or 0, "disk": flavor.get("disk_gb") or 0}
        fits, limited_by, known = 0, "", False
        for row in hypervisors:
            allocation = row.get("allocation") or {}
            if not allocation.get("source") or not _schedulable(row):
                continue
            per_host, host_limit = None, ""
            for key, need in demand.items():
                entry = allocation.get(key)
                if not need or not entry:
                    continue
                possible = entry["free"] // need
                if per_host is None or possible < per_host:
                    per_host, host_limit = possible, key
            if per_host is None:
                continue
            known = True
            fits += per_host
            if per_host == 0 and not limited_by:
                limited_by = host_limit
            elif host_limit and not limited_by:
                limited_by = host_limit
        results.append({"name": flavor.get("name", ""), "vcpus": demand["vcpu"], "ram_mb": demand["memory"], "disk_gb": demand["disk"],
                        "fits": fits if known else None, "limited_by": limited_by if known else ""})
    return results


def _recompute_capacity(capacity: dict) -> dict:
    """Roll per-hypervisor numbers up into totals, availability zones and flavor headroom.

    Called again after nova.conf ratios are merged in, so every derived number stays consistent
    with whatever allocation source each hypervisor ended up with.
    """
    hypervisors = capacity.get("hypervisors", [])
    totals = capacity["totals"]
    sources = {row.get("allocation", {}).get("source", "") for row in hypervisors if row.get("allocation", {}).get("source")}
    overcommit = {"source": "placement" if "placement" in sources else ("nova.conf" if "nova.conf" in sources else ""),
                  "mixed": len(sources) > 1, "known_hypervisors": sum(1 for row in hypervisors if row.get("allocation", {}).get("source"))}
    for key, unit in (("vcpu", "vcpus"), ("memory", "memory_mb"), ("disk", "local_gb")):
        entries = [row["allocation"][key] for row in hypervisors if (row.get("allocation") or {}).get(key)]
        capacity_sum = sum(entry["capacity"] for entry in entries)
        used_sum = sum(entry["used"] for entry in entries)
        ratios = {entry["ratio"] for entry in entries}
        overcommit[unit] = {"capacity": capacity_sum, "used": used_sum, "free": max(0, capacity_sum - used_sum),
                            "percent": _percent(used_sum, capacity_sum), "reserved": sum(entry["reserved"] for entry in entries),
                            "ratio": round(sum(ratios) / len(ratios), 3) if len(ratios) == 1 else (round(sum(entry["ratio"] for entry in entries) / len(entries), 3) if entries else None),
                            "uniform_ratio": len(ratios) == 1}
    totals["overcommit"] = overcommit
    zones: dict[str, dict] = {}
    # With no aggregates collected every hypervisor would land in one nameless bucket, which says
    # nothing; leave the section empty instead so the panel can hide it.
    for row in hypervisors if any(row.get("availability_zone") for row in hypervisors) else []:
        zone = zones.setdefault(row.get("availability_zone") or "-", {"name": row.get("availability_zone") or "-", "hypervisors": 0, "hypervisors_up": 0,
                                                                     "instances": 0, "vcpus": 0, "vcpus_used": 0, "memory_mb": 0, "memory_mb_used": 0, "local_gb": 0, "local_gb_used": 0,
                                                                     "vcpu_capacity": 0, "vcpu_allocated": 0})
        zone["hypervisors"] += 1
        zone["hypervisors_up"] += 1 if str(row.get("state", "")).lower() == "up" else 0
        zone["instances"] += row.get("instances") or 0
        for field in ("vcpus", "vcpus_used", "memory_mb", "memory_mb_used", "local_gb", "local_gb_used"):
            zone[field] += row.get(field) or 0
        vcpu = (row.get("allocation") or {}).get("vcpu")
        if vcpu:
            zone["vcpu_capacity"] += vcpu["capacity"]
            zone["vcpu_allocated"] += vcpu["used"]
    for zone in zones.values():
        zone["vcpu_percent"] = _percent(zone["vcpus_used"], zone["vcpus"])
        zone["vcpu_overcommit_percent"] = _percent(zone["vcpu_allocated"], zone["vcpu_capacity"])
    capacity["zones"] = sorted(zones.values(), key=lambda item: (-item["hypervisors"], item["name"]))
    capacity["headroom"]["results"] = _headroom(hypervisors, capacity["headroom"]["flavors"])
    return capacity


def _headroom_flavors(servers: list[dict], flavors: list[dict]) -> list[dict]:
    """Flavors worth planning with: the ones already in use, most-used first, then any others."""
    usage: dict[str, int] = {}
    for server in servers:
        if server.get("flavor"):
            usage[server["flavor"]] = usage.get(server["flavor"], 0) + 1
    unique = {flavor["name"]: flavor for flavor in flavors if flavor.get("name")}
    ordered = sorted(unique.values(), key=lambda flavor: (-usage.get(flavor["name"], 0), flavor["name"]))
    return [{"name": flavor["name"], "vcpus": flavor.get("vcpus") or 0, "ram_mb": flavor.get("ram_mb") or 0, "disk_gb": flavor.get("disk_gb") or 0}
            for flavor in ordered[:MAX_HEADROOM_FLAVORS]]


def build_capacity(hypervisors: list[dict], servers: list[dict], projects: dict[str, str], placement: dict | None = None,
                   quotas: dict[str, dict] | None = None, zones: dict[str, str] | None = None, flavors: list[dict] | None = None) -> dict:
    totals = {"vcpus": sum(h["vcpus"] for h in hypervisors), "vcpus_used": sum(h["vcpus_used"] for h in hypervisors),
              "memory_mb": sum(h["memory_mb"] for h in hypervisors), "memory_mb_used": sum(h["memory_mb_used"] for h in hypervisors),
              "local_gb": sum(h["local_gb"] for h in hypervisors), "local_gb_used": sum(h["local_gb_used"] for h in hypervisors),
              "running_vms": sum(h["running_vms"] for h in hypervisors), "hypervisors": len(hypervisors),
              "hypervisors_up": sum(1 for h in hypervisors if h["state"].lower() == "up")}
    totals.update({"vcpu_percent": _percent(totals["vcpus_used"], totals["vcpus"]), "memory_percent": _percent(totals["memory_mb_used"], totals["memory_mb"]), "disk_percent": _percent(totals["local_gb_used"], totals["local_gb"])})
    providers = (placement or {}).get("providers") or {}
    per_hypervisor = []
    for h in hypervisors:
        short = h["hostname"].split(".")[0]
        row = {**h, "vcpu_percent": _percent(h["vcpus_used"], h["vcpus"]), "memory_percent": _percent(h["memory_mb_used"], h["memory_mb"]), "disk_percent": _percent(h["local_gb_used"], h["local_gb"]),
               "instances": sum(1 for server in servers if server["host"] and server["host"].split(".")[0] == short),
               "availability_zone": (zones or {}).get(short, "")}
        row["allocation"] = _allocation_for(row, providers.get(short), None)
        per_hypervisor.append(row)
    by_project: dict[str, dict] = {}
    for server in servers:
        entry = by_project.setdefault(server["project_id"], {"id": server["project_id"], "name": projects.get(server["project_id"], server["project_id"] or "-"), "instances": 0, "active": 0, "vcpus": 0, "ram_mb": 0, "disk_gb": 0})
        entry["instances"] += 1
        entry["active"] += 1 if server["status"].upper() == "ACTIVE" else 0
        entry["vcpus"] += server.get("vcpus") or 0
        entry["ram_mb"] += server.get("ram_mb") or 0
        entry["disk_gb"] += server.get("disk_gb") or 0
    for project_id, name in (projects or {}).items():
        # A project with a quota but no instances still matters when its quota is nearly used up.
        if project_id in (quotas or {}) and project_id not in by_project:
            by_project[project_id] = {"id": project_id, "name": name, "instances": 0, "active": 0, "vcpus": 0, "ram_mb": 0, "disk_gb": 0}
    for project_id, entry in by_project.items():
        entry["quota"] = build_project_quota(entry, (quotas or {}).get(project_id) or {})
    status_counts: dict[str, int] = {}
    for server in servers:
        status_counts[server["status"] or "-"] = status_counts.get(server["status"] or "-", 0) + 1
    capacity = {"hypervisors": per_hypervisor, "totals": totals, "projects": sorted(by_project.values(), key=lambda item: (-item["vcpus"], item["name"])),
                "instances": {"total": len(servers), "by_status": status_counts},
                "quota_available": bool(quotas), "headroom": {"flavors": _headroom_flavors(servers, flavors or []), "results": []}}
    return _recompute_capacity(capacity)


QUOTA_LABELS = {"instances": "인스턴스", "vcpus": "vCPU", "ram_mb": "메모리", "volumes": "볼륨", "disk_gb": "볼륨 용량",
                "snapshots": "스냅샷", "floating_ips": "Floating IP", "networks": "네트워크", "ports": "포트",
                "routers": "라우터", "security_groups": "보안 그룹"}


def build_project_quota(usage: dict, quota: dict) -> dict:
    """Per-project quota vs. usage. Quota `used` is authoritative; instance totals are the fallback.

    A limit of -1 is unlimited, so it has no percentage and can never be exceeded.
    """
    resources = {}
    for key, label in QUOTA_LABELS.items():
        item = quota.get(key)
        if item is None:
            fallback = usage.get(key if key != "vcpus" else "vcpus")
            if key in ("instances", "vcpus", "ram_mb") and fallback:
                resources[key] = {"label": label, "used": fallback, "limit": -1, "percent": None, "unlimited": True, "estimated": True}
            continue
        limit = item["limit"]
        unlimited = limit is None or limit < 0
        resources[key] = {"label": label, "used": item["used"], "limit": limit, "unlimited": unlimited,
                          "percent": None if unlimited else _percent(item["used"], limit), "estimated": False}
    exceeded = [key for key, item in resources.items() if not item["unlimited"] and item["limit"] and item["used"] >= item["limit"]]
    near = [key for key, item in resources.items() if not item["unlimited"] and (item["percent"] or 0) >= 80 and key not in exceeded]
    return {"resources": resources, "available": bool(quota), "exceeded": exceeded, "near_limit": near,
            "worst_percent": max([item["percent"] for item in resources.values() if item["percent"] is not None], default=None)}


def apply_node_allocation_ratios(capacity: dict, nodes: list[dict]) -> dict:
    """Fill in overcommit for hypervisors Placement did not cover, using each node's nova.conf.

    Placement is preferred because an operator can change a provider's ratio there without editing
    nova.conf; this only touches hypervisors that got nothing from Placement.
    """
    by_host = {str(node.get("hostname", "")).split(".")[0]: node.get("nova_conf") for node in nodes if (node.get("nova_conf") or {}).get("ratios")}
    changed = False
    for row in capacity.get("hypervisors", []):
        if (row.get("allocation") or {}).get("source"):
            continue
        allocation = _allocation_for(row, None, by_host.get(row["hostname"].split(".")[0]))
        if allocation.get("source"):
            row["allocation"] = allocation
            changed = True
    return _recompute_capacity(capacity) if changed else capacity


def build_storage(ceph: dict | None, nfs: dict) -> dict:
    backend = "ceph" if ceph else ("nfs" if nfs["mounts"] else "none")
    return {"backend": backend, "ceph": ceph, "nfs": nfs}


# --- helpers for the driver -----------------------------------------------------------------------

def node_script(command_timeout: int) -> str:
    return f"T_CMD={int(command_timeout)}\n" + NODE_SCRIPT


def controller_script(command_timeout: int) -> str:
    return f"T_CMD={int(command_timeout)}\n" + CONTROLLER_SCRIPT


def quote(value: str) -> str:
    return shlex.quote(value)
