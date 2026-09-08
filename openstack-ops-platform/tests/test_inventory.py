"""Infrastructure inventory: parsers against captured command output, the store, and the SSH driver
run end-to-end against a fake connection that executes the real scripts on localhost."""
from __future__ import annotations

import asyncio
import base64
import json
from types import SimpleNamespace

import pytest

import inventory_collector as ic
import provider_store
import server


def section(name: str, output: str, rc: int = 0) -> str:
    return f"section={name}|{rc}|{base64.b64encode(output.encode()).decode()}"


LSCPU = """Architecture:                    x86_64
CPU(s):                          32
Thread(s) per core:              2
Core(s) per socket:              8
Socket(s):                       2
Model name:                      Intel(R) Xeon(R) Silver 4208 CPU @ 2.10GHz
Hypervisor vendor:               KVM
"""
LSBLK = '''NAME="sda" SIZE="480103981056" TYPE="disk" MOUNTPOINT="" MODEL="SAMSUNG MZ7LH480" ROTA="0"
NAME="sda1" SIZE="1048576" TYPE="part" MOUNTPOINT="" MODEL="" ROTA="0"
NAME="sdb" SIZE="2000398934016" TYPE="disk" MOUNTPOINT="" MODEL="ST2000NM" ROTA="1"
'''
DF = """Filesystem     1-blocks       Used  Available Capacity Mounted on
/dev/sda2     100000000000 91000000000 9000000000  91% /
/dev/sdb1     200000000000 50000000000 150000000000 25% /var/lib/nova/instances
"""
IP_LINK = """lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
ens3             UP             52:54:00:12:34:56 <BROADCAST,MULTICAST,UP,LOWER_UP>
bond0            UP             52:54:00:aa:bb:cc <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP>
vlan10@bond0     UP             52:54:00:aa:bb:cc <BROADCAST,MULTICAST,UP,LOWER_UP>
"""
IP_ADDR = """lo               UNKNOWN        127.0.0.1/8 ::1/128
ens3             UP             10.255.191.151/24 fe80::1/64
bond0            UP             10.0.0.5/24
"""
BONDING = """=== bond0
Ethernet Channel Bonding Driver: v5.15.0

Bonding Mode: IEEE 802.3ad Dynamic link aggregation
MII Status: up
Currently Active Slave: None

Slave Interface: ens4
MII Status: up
Speed: 10000 Mbps

Slave Interface: ens5
MII Status: down
Speed: Unknown
"""
VIRSH = """ Id   Name                State
-----------------------------------
 1    instance-00000001   running
 -    instance-00000002   shut off
"""
HYPERVISORS = json.dumps([{"ID": 1, "Hypervisor Hostname": "hcom01", "Hypervisor Type": "QEMU", "Host IP": "10.255.191.154", "State": "up", "vCPUs Used": 12, "vCPUs": 32, "Memory MB Used": 24576, "Memory MB": 131072},
                          {"ID": 2, "Hypervisor Hostname": "hcom02", "Hypervisor Type": "QEMU", "Host IP": "10.255.191.155", "State": "down", "vCPUs Used": 0, "vCPUs": 32, "Memory MB Used": 512, "Memory MB": 131072}])
HV_SHOW = json.dumps({"local_gb": 1800, "local_gb_used": 300, "running_vms": 3, "status": "enabled"})
SERVERS = json.dumps([{"ID": "s1", "Name": "web-1", "Status": "ACTIVE", "Host": "hcom01", "Project ID": "p1", "Flavor Name": "m1.large", "Networks": {"private": ["10.0.0.11"]}},
                      {"ID": "s2", "Name": "db-1", "Status": "ERROR", "Host": "hcom01", "Project ID": "p2", "Flavor": {"id": "f2", "original_name": "m1.small"}, "Networks": "private=10.0.0.12"},
                      {"ID": "s3", "Name": "app-1", "Status": "ACTIVE", "Host": "hcom01", "Project ID": "p1", "Flavor Name": "m1.large", "Networks": {}}])
FLAVORS = json.dumps([{"ID": "f1", "Name": "m1.large", "RAM": 8192, "Disk": 80, "VCPUs": 4}, {"ID": "f2", "Name": "m1.small", "RAM": 2048, "Disk": 20, "VCPUs": 1}])
PROJECTS = json.dumps([{"ID": "p1", "Name": "platform"}, {"ID": "p2", "Name": "database"}])
VOLUMES = json.dumps([{"ID": "v1", "Name": "data", "Status": "in-use", "Size": 100, "Type": "nfs", "Attached to": [{"server_id": "s1", "device": "/dev/vdb"}]}])
NETWORKS = json.dumps([{"ID": "n1", "Name": "public", "Status": "ACTIVE", "Router Type": "External", "Subnets": ["a"]}, {"ID": "n2", "Name": "private", "Status": "ACTIVE", "Subnets": ["b", "c"]}])
CEPH = json.dumps({"fsid": "abc", "health": {"status": "HEALTH_WARN", "checks": {"OSD_DOWN": {"summary": {"message": "1 osds down"}}}},
                   "osdmap": {"osdmap": {"num_osds": 6, "num_up_osds": 5, "num_in_osds": 6}}, "pgmap": {"bytes_used": 2 * 10**12, "bytes_total": 10 * 10**12, "bytes_avail": 8 * 10**12, "num_pgs": 256, "num_pools": 4}})
MOUNTS = "nfs01:/export/glance /var/lib/glance/images nfs4 rw,relatime 0 0\nnfs01:/export/cinder /var/lib/cinder/mnt/abc nfs rw 0 0\n"
DF_NFS = "Filesystem 1-blocks Used Available Capacity Mounted on\nnfs01:/export/glance 1000 850 150 85% /var/lib/glance/images\n"


def node_stdout(**overrides) -> str:
    parts = {
        "hostname": "hcom01", "os": 'PRETTY_NAME="Ubuntu 22.04.4 LTS"\nID=ubuntu\nVERSION_ID="22.04"\n', "kernel": "5.15.0-47-generic\n", "lscpu": LSCPU,
        "meminfo": "MemTotal:       131072000 kB\nSwapTotal:       8388604 kB\n", "lsblk": LSBLK, "df": DF, "ip_link": IP_LINK, "ip_addr": IP_ADDR, "bonding": BONDING,
        "services": "nova-compute.service\nlibvirtd.service\nopenvswitch-switch.service\n", "uptime": "1234567.89 9876.54\n", "virsh": VIRSH,
    }
    parts.update(overrides)
    return "\n".join(section(name, output) for name, output in parts.items()) + "\n"


def controller_stdout(**overrides) -> str:
    parts = {"hostname": "hcon03", "openrc": "/root/contrabass-openrc\n", "hypervisors": HYPERVISORS, "hypervisor_stats": "{}", "servers": SERVERS, "volumes": VOLUMES,
             "networks": NETWORKS, "projects": PROJECTS, "flavors": FLAVORS, "ceph": CEPH, "mounts": MOUNTS, "df_nfs": DF_NFS, "cinder_mounts": "abc\n", "hypervisor_show|hcom01": HV_SHOW}
    parts.update(overrides)
    return "\n".join(section(name, output) for name, output in parts.items()) + "\n"


# --- parsers -------------------------------------------------------------------------------------

def test_parse_sections_tolerates_noise_and_pipes_in_names():
    stdout = "garbage line\n" + section("hypervisor_show|hcom01", "{}") + "\n" + section("df", "x", rc=1) + "\nsection=broken\n"
    sections = ic.parse_sections(stdout)
    assert sections["hypervisor_show|hcom01"] == {"rc": 0, "output": "{}"}
    assert sections["df"]["rc"] == 1 and "broken" not in sections


def test_parse_node_output_covers_every_section():
    node = ic.parse_node_output(node_stdout())
    assert node["reported_hostname"] == "hcom01"
    assert node["os"]["name"] == "Ubuntu 22.04.4 LTS" and node["kernel"] == "5.15.0-47-generic"
    assert node["cpu"]["model"].startswith("Intel") and node["cpu"]["cpus"] == 32 and node["cpu"]["sockets"] == 2 and node["cpu"]["hypervisor_vendor"] == "KVM"
    assert node["memory_total_kb"] == 131072000 and node["swap_total_kb"] == 8388604 and node["uptime_seconds"] == 1234567
    assert [disk["name"] for disk in node["disks"]] == ["sda", "sdb"] and node["disks"][0]["rotational"] is False and node["disks"][1]["size_bytes"] == 2000398934016
    assert len(node["block_devices"]) == 3
    assert node["filesystems"][0]["mountpoint"] == "/" and node["filesystems"][0]["use_percent"] == 91 and node["filesystems"][1]["mountpoint"] == "/var/lib/nova/instances"
    names = [nic["name"] for nic in node["interfaces"]]
    assert names == ["ens3", "bond0", "vlan10"] and node["interfaces"][0]["addresses"] == ["10.255.191.151/24", "fe80::1/64"] and node["interfaces"][0]["mac"] == "52:54:00:12:34:56"
    bond = node["bonds"][0]
    assert bond["name"] == "bond0" and bond["mode"].startswith("IEEE 802.3ad") and bond["mii_status"] == "up"
    assert [(slave["name"], slave["mii_status"], slave["speed"]) for slave in bond["slaves"]] == [("ens4", "up", "10000 Mbps"), ("ens5", "down", "Unknown")]
    assert node["services"] == ["nova-compute.service", "libvirtd.service", "openvswitch-switch.service"]
    assert node["vms"] == [{"name": "instance-00000001", "state": "running"}, {"name": "instance-00000002", "state": "shut off"}] and node["virsh_available"]
    assert node["sections_ok"] == node["sections_total"] == 13


def test_parse_node_output_without_virsh_or_bonds():
    node = ic.parse_node_output(node_stdout(virsh="", bonding=""))
    assert node["vms"] == [] and node["bonds"] == []
    failed = ic.parse_node_output("\n".join([section("virsh", "virsh not installed", rc=90), section("services", "", rc=1)]))
    assert failed["virsh_available"] is False and failed["services"] == [] and failed["uptime_seconds"] is None


def test_parse_controller_output_capacity_projects_and_storage():
    result = ic.parse_controller_output(controller_stdout())
    os_ = result["openstack"]
    assert os_["available"] and os_["openrc"] == "/root/contrabass-openrc" and os_["errors"] == {}
    hv = {item["hostname"]: item for item in os_["hypervisors"]}
    assert hv["hcom01"]["local_gb"] == 1800 and hv["hcom01"]["local_gb_used"] == 300 and hv["hcom01"]["running_vms"] == 3 and hv["hcom01"]["status"] == "enabled"
    assert hv["hcom02"]["local_gb"] == 0 and hv["hcom02"]["state"] == "down"
    servers = {server["name"]: server for server in os_["servers"]}
    assert servers["web-1"]["vcpus"] == 4 and servers["web-1"]["ram_mb"] == 8192 and servers["web-1"]["networks"] == "private=10.0.0.11"
    assert servers["db-1"]["flavor"] == "m1.small" and servers["db-1"]["vcpus"] == 1  # flavor given as a dict with id
    assert os_["volumes"][0]["attached_to"] == "s1" and os_["volumes"][0]["size_gb"] == 100
    assert os_["networks"][0]["external"] is True and os_["networks"][1]["subnets"] == 2
    capacity = result["capacity"]
    assert capacity["totals"]["vcpus"] == 64 and capacity["totals"]["vcpus_used"] == 12 and capacity["totals"]["vcpu_percent"] == 18.8
    assert capacity["totals"]["hypervisors_up"] == 1 and capacity["totals"]["running_vms"] == 3
    per = {item["hostname"]: item for item in capacity["hypervisors"]}
    assert per["hcom01"]["instances"] == 3 and per["hcom01"]["disk_percent"] == 16.7 and per["hcom02"]["disk_percent"] is None
    projects = {item["name"]: item for item in capacity["projects"]}
    assert {key: value for key, value in projects["platform"].items() if key != "quota"} == {"id": "p1", "name": "platform", "instances": 2, "active": 2, "vcpus": 8, "ram_mb": 16384, "disk_gb": 160}
    assert projects["platform"]["quota"]["available"] is False  # no quota sections in this fixture
    assert projects["database"]["instances"] == 1 and projects["database"]["active"] == 0
    assert capacity["instances"] == {"total": 3, "by_status": {"ACTIVE": 2, "ERROR": 1}}
    storage = result["storage"]
    assert storage["backend"] == "ceph" and storage["ceph"]["health"] == "HEALTH_WARN" and storage["ceph"]["osds_up"] == 5 and storage["ceph"]["warnings"] == ["OSD_DOWN: 1 osds down"]
    assert storage["nfs"]["glance_on_nfs"] and storage["nfs"]["cinder_on_nfs"] and storage["nfs"]["mounts"][0]["use_percent"] == 85 and storage["nfs"]["mounts"][0]["serves"] == ["Glance 이미지"]
    assert storage["nfs"]["cinder_mount_dirs"] == ["abc"]


def test_parse_controller_output_when_openstack_cli_fails():
    stdout = "\n".join([section("hostname", "hcon03"), section("openrc", "OpenRC 파일을 찾을 수 없습니다", rc=78), section("hypervisors", "bash: openstack: command not found", rc=127),
                        section("ceph", "ceph not installed", rc=90), section("mounts", ""), section("df_nfs", "")])
    result = ic.parse_controller_output(stdout)
    assert result["openstack"]["available"] is False
    assert "openrc" in result["openstack"]["errors"] and "command not found" in result["openstack"]["errors"]["hypervisors"]
    assert result["capacity"]["hypervisors"] == [] and result["capacity"]["totals"]["vcpus"] == 0
    assert result["storage"]["backend"] == "none" and result["storage"]["ceph"] is None


PLACEMENT_RPS = json.dumps({"resource_providers": [
    {"uuid": "rp-1", "name": "hcom01", "parent_provider_uuid": None},
    {"uuid": "rp-2", "name": "hcom02", "parent_provider_uuid": None},
    {"uuid": "rp-3", "name": "hcom01_pgpu", "parent_provider_uuid": "rp-1"}]})
PLACEMENT_INV_1 = json.dumps({"inventories": {
    "VCPU": {"total": 32, "reserved": 0, "allocation_ratio": 16.0, "min_unit": 1, "step_size": 1},
    "MEMORY_MB": {"total": 131072, "reserved": 512, "allocation_ratio": 1.5},
    "DISK_GB": {"total": 1800, "reserved": 0, "allocation_ratio": 1.0}}})
PLACEMENT_USE_1 = json.dumps({"usages": {"VCPU": 12, "MEMORY_MB": 24576, "DISK_GB": 300}})
QUOTA_COMPUTE = json.dumps({"quota_set": {"id": "p1", "instances": {"in_use": 2, "reserved": 0, "limit": 10},
                                          "cores": {"in_use": 8, "reserved": 0, "limit": 100},
                                          "ram": {"in_use": 16384, "reserved": 0, "limit": 51200}}})
QUOTA_VOLUME = json.dumps({"quota_set": {"id": "p1", "volumes": {"in_use": 3, "reserved": 0, "limit": 10},
                                         "gigabytes": {"in_use": 160, "reserved": 0, "limit": -1}}})
QUOTA_NETWORK = json.dumps({"quota": {"floatingip": {"used": 3, "reserved": 0, "limit": 50},
                                      "network": {"used": 2, "reserved": 0, "limit": 10}}})
AGGREGATES = json.dumps([{"ID": 1, "Name": "az-a-hosts", "Availability Zone": "az-a", "Hosts": ["hcom01"]},
                         {"ID": 2, "Name": "az-b-hosts", "Availability Zone": "az-b", "Hosts": "hcom02"}])
NOVA_CONF = """=== /etc/nova/nova.conf
cpu_allocation_ratio = 0.0
initial_cpu_allocation_ratio = 8.0
ram_allocation_ratio = 1.2
reserved_host_memory_mb = 4096
=== /etc/nova/nova.conf.d/override.conf
ram_allocation_ratio = 2.0
"""


def controller_with_apis(**overrides) -> str:
    parts = {"api_access": "placement=http://p compute=http://c volume=http://v network=http://n",
             "placement_providers": PLACEMENT_RPS, "placement_inv|rp-1": PLACEMENT_INV_1, "placement_use|rp-1": PLACEMENT_USE_1,
             "quota_compute|p1": QUOTA_COMPUTE, "quota_volume|p1": QUOTA_VOLUME, "quota_network|p1": QUOTA_NETWORK,
             "aggregates": AGGREGATES}
    parts.update(overrides)
    return controller_stdout(**parts)


def test_parse_nova_conf_prefers_configured_over_initial_and_later_files():
    parsed = ic.parse_nova_conf(NOVA_CONF)
    # cpu is configured as 0.0, which nova treats as "unset", so the initial_ value stands.
    assert parsed["ratios"]["vcpu"] == 8.0
    # the drop-in file is read after the base file and wins.
    assert parsed["ratios"]["memory"] == 2.0
    assert "disk" not in parsed["ratios"]
    assert parsed["reserved"] == {"vcpu": 0, "memory": 4096, "disk": 0.0}
    assert parsed["files"] == ["/etc/nova/nova.conf", "/etc/nova/nova.conf.d/override.conf"]
    assert ic.parse_nova_conf("")["ratios"] == {}


def test_placement_drives_overcommit_capacity_and_headroom():
    result = ic.parse_controller_output(controller_with_apis())
    capacity = result["capacity"]
    assert result["api_access"]["ok"] and result["api_access"]["placement"] and result["api_access"]["quota_projects"] == 1
    rows = {row["hostname"]: row for row in capacity["hypervisors"]}
    allocation = rows["hcom01"]["allocation"]
    assert allocation["source"] == "placement"
    # 32 cores x 16 = 512 schedulable vCPU; nova reports 12 allocated.
    assert allocation["vcpu"] == {"total": 32, "reserved": 0, "ratio": 16.0, "capacity": 512, "used": 12, "percent": 2.3, "physical_percent": 37.5, "free": 500}
    # memory reserves 512 MB before the 1.5 ratio applies: (131072 - 512) * 1.5
    assert allocation["memory"]["capacity"] == 195840 and allocation["memory"]["used"] == 24576
    assert rows["hcom02"]["allocation"]["source"] == "", "the nested pgpu provider must not be matched to a hypervisor"
    overcommit = capacity["totals"]["overcommit"]
    assert overcommit["source"] == "placement" and overcommit["known_hypervisors"] == 1 and overcommit["mixed"] is False
    assert overcommit["vcpus"] == {"capacity": 512, "used": 12, "free": 500, "percent": 2.3, "reserved": 0, "ratio": 16.0, "uniform_ratio": True}
    headroom = {item["name"]: item for item in capacity["headroom"]["results"]}
    # only hcom01 is up with a known allocation: 500 free vCPU / 4, 171264 free MB / 8192, 1500 free GB / 80.
    assert headroom["m1.large"]["fits"] == 18 and headroom["m1.large"]["limited_by"] == "disk"
    assert headroom["m1.small"]["fits"] == 75 and headroom["m1.small"]["limited_by"] == "disk"
    zones = {zone["name"]: zone for zone in capacity["zones"]}
    assert zones["az-a"]["vcpu_capacity"] == 512 and zones["az-b"]["hypervisors_up"] == 0


def test_project_quota_merges_compute_volume_and_network():
    capacity = ic.parse_controller_output(controller_with_apis())["capacity"]
    assert capacity["quota_available"] is True
    projects = {item["id"]: item for item in capacity["projects"]}
    quota = projects["p1"]["quota"]
    assert quota["available"] and quota["resources"]["vcpus"] == {"label": "vCPU", "used": 8, "limit": 100, "unlimited": False, "percent": 8.0, "estimated": False}
    assert quota["resources"]["disk_gb"]["unlimited"] is True and quota["resources"]["disk_gb"]["percent"] is None
    assert quota["resources"]["floating_ips"]["used"] == 3 and quota["resources"]["networks"]["limit"] == 10
    assert quota["exceeded"] == [] and quota["near_limit"] == [] and quota["worst_percent"] == 32.0
    # p2 has instances but no quota sections, so it falls back to the estimate from its instances.
    assert projects["p2"]["quota"]["available"] is False and projects["p2"]["quota"]["resources"]["vcpus"]["estimated"] is True


def test_quota_exceeded_and_near_limit_are_flagged():
    tight = json.dumps({"quota_set": {"id": "p1", "instances": {"in_use": 10, "reserved": 0, "limit": 10},
                                      "cores": {"in_use": 85, "reserved": 0, "limit": 100}}})
    capacity = ic.parse_controller_output(controller_with_apis(**{"quota_compute|p1": tight}))["capacity"]
    quota = {item["id"]: item for item in capacity["projects"]}["p1"]["quota"]
    assert quota["exceeded"] == ["instances"] and quota["near_limit"] == ["vcpus"] and quota["worst_percent"] == 100.0


def test_nova_conf_fills_hypervisors_placement_did_not_cover():
    capacity = ic.parse_controller_output(controller_with_apis())["capacity"]
    nodes = [{"hostname": "hcom02.example.com", "nova_conf": ic.parse_nova_conf(NOVA_CONF)},
             {"hostname": "hcom01", "nova_conf": {"ratios": {"vcpu": 99.0}, "reserved": {}}}]
    ic.apply_node_allocation_ratios(capacity, nodes)
    rows = {row["hostname"]: row for row in capacity["hypervisors"]}
    assert rows["hcom01"]["allocation"]["vcpu"]["ratio"] == 16.0, "placement must win over nova.conf"
    fallback = rows["hcom02"]["allocation"]
    assert fallback["source"] == "nova.conf" and fallback["vcpu"]["capacity"] == 32 * 8
    assert fallback["memory"]["capacity"] == int((131072 - 4096) * 2.0)
    assert "disk" not in fallback, "nova.conf sets no disk ratio, so disk stays unknown"
    assert capacity["totals"]["overcommit"]["mixed"] is True and capacity["totals"]["overcommit"]["known_hypervisors"] == 2
    # hcom02 is down, so the extra capacity must not appear as headroom.
    assert {item["name"]: item["fits"] for item in capacity["headroom"]["results"]}["m1.large"] == 18


def test_api_sections_absent_leaves_capacity_usable():
    capacity = ic.parse_controller_output(controller_stdout())["capacity"]
    assert capacity["quota_available"] is False and capacity["zones"] == []
    assert all(row["allocation"] == {"source": ""} for row in capacity["hypervisors"])
    assert capacity["totals"]["overcommit"]["source"] == "" and capacity["totals"]["overcommit"]["vcpus"]["capacity"] == 0
    assert [item["fits"] for item in capacity["headroom"]["results"]] == [None, None]


def test_placement_and_quota_failures_are_reported_not_raised():
    stdout = controller_with_apis(**{"placement_providers": "401 Unauthorized"})
    keep = [line for line in stdout.splitlines() if "placement_inv|" not in line and "placement_use|" not in line and "section=api_access|" not in line]
    stdout = "\n".join(keep + [section("api_access", "인증 토큰을 발급하지 못했습니다", rc=77)])
    result = ic.parse_controller_output(stdout)
    assert result["api_access"]["ok"] is False and result["api_access"]["placement"] is False
    assert result["capacity"]["totals"]["overcommit"]["known_hypervisors"] == 0


def test_scripts_use_timeouts_and_stdin_guard():
    script = ic.node_script(25)
    assert script.startswith("T_CMD=25\n") and 'timeout -k 5 "$T_CMD"' in script and "</dev/null" in script
    controller = ic.controller_script(30)
    assert "openstack hypervisor list --long -f json" in controller and "openstack server list --all-projects --long --limit 2000 -f json" in controller
    assert "/root/contrabass-openrc" in controller and "ceph -s -f json" in controller and "/proc/mounts" in controller


# --- store ---------------------------------------------------------------------------------------

def test_inventory_store_keeps_last_ten(provider_id):
    for index in range(12):
        provider_store.save_inventory(provider_id, "healthy", 1.5, {"nodes": [{"reachable": True}], "capacity": {"totals": {"hypervisors": 1}, "instances": {"total": index}}, "storage": {"backend": "nfs"}})
    history = provider_store.list_inventories(provider_id, 20)
    assert len(history) == 10 and history[0]["instances"] == 11 and history[-1]["instances"] == 2
    latest = provider_store.latest_inventory(provider_id)
    assert latest["payload"]["capacity"]["instances"]["total"] == 11 and latest["reachable_nodes"] == 1 and latest["storage_backend"] == "nfs"
    assert provider_store.get_inventory(provider_id, history[3]["id"])["instances"] == 8
    assert provider_store.delete_provider(provider_id)
    assert provider_store.list_inventories(provider_id) == []


# --- routes --------------------------------------------------------------------------------------

def test_inventory_routes_empty_and_progress(auth_client, provider_id):
    response = auth_client.get(f"/api/providers/{provider_id}/inventory")
    assert response.status_code == 200
    assert response.json()["inventory"] is None and response.json()["running"] is False
    assert auth_client.get(f"/api/providers/{provider_id}/inventory?history=1").json()["history"] == []
    assert auth_client.get(f"/api/providers/{provider_id}/inventory?inventory_id=missing").status_code == 404
    progress = auth_client.get(f"/api/providers/{provider_id}/inventory/progress").json()
    assert progress == {"running": False, "stage": "idle", "message": "실행 중인 인벤토리 수집이 없습니다.", "percent": 0}
    assert auth_client.get("/api/providers/nope/inventory").status_code == 404
    assert auth_client.post("/api/providers/nope/inventory/collect").status_code == 404


def test_collect_requires_discovered_nodes(auth_client):
    new_id = provider_store.save_provider({"name": "empty", "vip": "192.0.2.99", "port": 22, "username": "root", "auth_method": "password", "fingerprint": "x",
                                          "controller_hostname": "c1", "sudo_mode": "root", "available_tools": []}, {"password": "x"})
    response = auth_client.post(f"/api/providers/{new_id}/inventory/collect")
    assert response.status_code == 409
    assert auth_client.get(f"/api/providers/{new_id}/inventory/progress").json()["stage"] == "failed"


def test_collect_conflicts_while_running(auth_client, provider_id):
    server.INVENTORY_PROGRESS[provider_id] = {"running": True, "stage": "nodes", "message": "x", "percent": 10}
    try:
        assert auth_client.post(f"/api/providers/{provider_id}/inventory/collect").status_code == 409
    finally:
        server.INVENTORY_PROGRESS.pop(provider_id, None)


class FakeConnection:
    """Runs the scripts on localhost. Non-root providers go through run_as_root's sudo path, which is
    answered here by treating the NOPASSWD probe as successful and executing `bash -s` directly."""

    def __init__(self, host: str, fail: bool = False):
        self.host = host
        self.fail = fail

    async def __aenter__(self):
        if self.fail:
            raise OSError("connection refused")
        return self

    async def __aexit__(self, *args):
        return False

    async def run(self, command: str, input: str | None = None, check: bool = False, timeout: int | None = None):
        if command == server.SUDO_PROBE_COMMAND:
            return SimpleNamespace(stdout="", stderr="", exit_status=0)
        assert command in {"bash -s", server.SUDO_NOPASSWD_COMMAND}, command
        process = await asyncio.create_subprocess_exec("bash", "-s", stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        stdout, stderr = await asyncio.wait_for(process.communicate((input or "").encode()), timeout=timeout or 120)
        return SimpleNamespace(stdout=stdout.decode("utf-8", errors="replace"), stderr=stderr.decode("utf-8", errors="replace"), exit_status=process.returncode)

    def get_server_host_key(self):
        return SimpleNamespace(get_fingerprint=lambda algorithm: "SHA256:fake")


def test_collect_end_to_end_with_fake_ssh(auth_client, provider_id, monkeypatch):
    """The real node and controller scripts run against localhost through the fake connection; one node
    is made unreachable to exercise the failure path, and `openstack` is absent here so the controller
    side must degrade gracefully."""
    def fake_connect(host, **options):
        return FakeConnection(host, fail=host == "192.0.2.12")

    async def fake_resolve(node):
        return node["address"]

    monkeypatch.setattr(server.asyncssh, "connect", fake_connect)
    monkeypatch.setattr(server, "resolve_node_address", fake_resolve)
    monkeypatch.setattr(server.socket, "gethostbyname", lambda name: "192.0.2.11")
    response = auth_client.post(f"/api/providers/{provider_id}/inventory/collect")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "warning" and body["summary"]["nodes"] == 3 and body["summary"]["reachable"] == 2
    assert body["summary"]["openstack_available"] is False
    latest = auth_client.get(f"/api/providers/{provider_id}/inventory").json()["inventory"]
    payload = latest["payload"]
    nodes = {node["hostname"]: node for node in payload["nodes"]}
    assert nodes["controller-2"]["reachable"] is False and nodes["controller-2"]["error"] == "OSError"
    good = nodes["controller-1"]
    assert good["reachable"] and good["kernel"] and good["cpu"]["cpus"] > 0 and good["memory_total_kb"] > 0 and good["filesystems"] and good["interfaces"]
    assert good["sections_ok"] >= 10
    assert payload["controller"]["target"] == "192.0.2.11" and payload["controller"]["error"] == ""
    assert "hypervisors" in payload["openstack"]["errors"] or "openrc" in payload["openstack"]["errors"]
    assert payload["storage"]["backend"] in {"none", "nfs"}
    progress = auth_client.get(f"/api/providers/{provider_id}/inventory/progress").json()
    assert progress["running"] is False and progress["stage"] == "done" and progress["percent"] == 100
    history = auth_client.get(f"/api/providers/{provider_id}/inventory?history=1").json()["history"]
    assert len(history) == 1 and history[0]["reachable_nodes"] == 2
    logs = auth_client.get("/api/audit-logs?action=inventory.collect").json()
    assert logs["total"] == 1 and logs["items"][0]["outcome"] == "success" and "노드 2/3대" in logs["items"][0]["detail"]
