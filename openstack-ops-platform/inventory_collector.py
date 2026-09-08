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
run servers 'openstack server list --all-projects --long --limit ''' + str(MAX_SERVERS) + r''' -f json'
run volumes 'openstack volume list --all-projects --long -f json'
run networks 'openstack network list --long -f json'
run projects 'openstack project list -f json'
run flavors 'openstack flavor list --all -f json'
run ceph 'if command -v ceph >/dev/null 2>&1; then timeout -k 5 20 ceph -s -f json </dev/null; else echo "ceph not installed"; exit 90; fi'
run mounts 'awk "\$3 ~ /^nfs/ {print}" /proc/mounts'
run df_nfs 'df -PB1 -t nfs -t nfs4 2>/dev/null || true'
run cinder_mounts 'ls -1 ''' + CINDER_MOUNT_PATH + r''' 2>/dev/null || true'
for name in $(openstack hypervisor list -f value -c "Hypervisor Hostname" 2>/dev/null </dev/null | head -n 30); do
  run "hypervisor_show|$name" "openstack hypervisor show -f json $(printf '%q' "$name")"
done
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
    return {
        "openstack": openstack,
        "capacity": build_capacity(hypervisors, servers, projects),
        "storage": build_storage(parse_ceph_status(ceph_data), parse_nfs_mounts(mounts_text, df_nfs, cinder_dirs)),
    }


def build_capacity(hypervisors: list[dict], servers: list[dict], projects: dict[str, str]) -> dict:
    def ratio(used: int, total: int) -> float | None:
        return round(used / total * 100, 1) if total else None
    totals = {"vcpus": sum(h["vcpus"] for h in hypervisors), "vcpus_used": sum(h["vcpus_used"] for h in hypervisors),
              "memory_mb": sum(h["memory_mb"] for h in hypervisors), "memory_mb_used": sum(h["memory_mb_used"] for h in hypervisors),
              "local_gb": sum(h["local_gb"] for h in hypervisors), "local_gb_used": sum(h["local_gb_used"] for h in hypervisors),
              "running_vms": sum(h["running_vms"] for h in hypervisors), "hypervisors": len(hypervisors),
              "hypervisors_up": sum(1 for h in hypervisors if h["state"].lower() == "up")}
    totals.update({"vcpu_percent": ratio(totals["vcpus_used"], totals["vcpus"]), "memory_percent": ratio(totals["memory_mb_used"], totals["memory_mb"]), "disk_percent": ratio(totals["local_gb_used"], totals["local_gb"])})
    per_hypervisor = [{**h, "vcpu_percent": ratio(h["vcpus_used"], h["vcpus"]), "memory_percent": ratio(h["memory_mb_used"], h["memory_mb"]), "disk_percent": ratio(h["local_gb_used"], h["local_gb"]),
                       "instances": sum(1 for server in servers if server["host"] and server["host"].split(".")[0] == h["hostname"].split(".")[0])} for h in hypervisors]
    by_project: dict[str, dict] = {}
    for server in servers:
        entry = by_project.setdefault(server["project_id"], {"id": server["project_id"], "name": projects.get(server["project_id"], server["project_id"] or "-"), "instances": 0, "active": 0, "vcpus": 0, "ram_mb": 0, "disk_gb": 0})
        entry["instances"] += 1
        entry["active"] += 1 if server["status"].upper() == "ACTIVE" else 0
        entry["vcpus"] += server.get("vcpus") or 0
        entry["ram_mb"] += server.get("ram_mb") or 0
        entry["disk_gb"] += server.get("disk_gb") or 0
    status_counts: dict[str, int] = {}
    for server in servers:
        status_counts[server["status"] or "-"] = status_counts.get(server["status"] or "-", 0) + 1
    return {"hypervisors": per_hypervisor, "totals": totals, "projects": sorted(by_project.values(), key=lambda item: (-item["vcpus"], item["name"])),
            "instances": {"total": len(servers), "by_status": status_counts}}


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
