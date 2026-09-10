"""Renders the upgraded infrastructure panels inside QuickJS and inspects the produced markup.

test_js_smoke only proves the modules load. These tests drive renderInventory() with real
inventory payloads so the overcommit basis toggle, the headroom table and the project quota
columns are exercised the way the browser would, without a browser.
"""
from __future__ import annotations

import json

import pytest
import quickjs

from js_harness import make_context


def hypervisor(hostname: str, *, vcpus=32, vcpus_used=12, memory=131072, memory_used=24576, local=1800, local_used=300,
               state="up", status="enabled", allocation=None, zone="") -> dict:
    row = {"id": hostname, "hostname": hostname, "type": "QEMU", "host_ip": "10.0.0.1", "state": state, "status": status,
           "vcpus": vcpus, "vcpus_used": vcpus_used, "memory_mb": memory, "memory_mb_used": memory_used,
           "local_gb": local, "local_gb_used": local_used, "running_vms": 3, "instances": 3,
           "vcpu_percent": round(vcpus_used / vcpus * 100, 1) if vcpus else None,
           "memory_percent": round(memory_used / memory * 100, 1) if memory else None,
           "disk_percent": round(local_used / local * 100, 1) if local else None,
           "availability_zone": zone, "allocation": allocation or {"source": ""}}
    return row


def allocation(ratio_vcpu=16.0, used_vcpu=12, total_vcpu=32) -> dict:
    capacity = int(total_vcpu * ratio_vcpu)
    return {"source": "placement",
            "vcpu": {"total": total_vcpu, "reserved": 0, "ratio": ratio_vcpu, "capacity": capacity, "used": used_vcpu,
                     "percent": round(used_vcpu / capacity * 100, 1), "physical_percent": round(used_vcpu / total_vcpu * 100, 1), "free": capacity - used_vcpu},
            "memory": {"total": 131072, "reserved": 512, "ratio": 1.5, "capacity": 195840, "used": 24576,
                       "percent": 12.5, "physical_percent": 18.8, "free": 171264},
            "disk": {"total": 1800, "reserved": 0, "ratio": 1.0, "capacity": 1800, "used": 300,
                     "percent": 16.7, "physical_percent": 16.7, "free": 1500}}


def payload(**overrides) -> dict:
    capacity = {
        "hypervisors": [hypervisor("hcom01", allocation=allocation(), zone="az-a"), hypervisor("hcom02", state="down", zone="az-b")],
        "totals": {"vcpus": 64, "vcpus_used": 12, "memory_mb": 262144, "memory_mb_used": 25088, "local_gb": 3600, "local_gb_used": 300,
                   "running_vms": 3, "hypervisors": 2, "hypervisors_up": 1, "vcpu_percent": 18.8, "memory_percent": 9.6, "disk_percent": 8.3,
                   "overcommit": {"source": "placement", "mixed": False, "known_hypervisors": 1,
                                  "vcpus": {"capacity": 512, "used": 12, "free": 500, "percent": 2.3, "reserved": 0, "ratio": 16.0, "uniform_ratio": True},
                                  "memory_mb": {"capacity": 195840, "used": 24576, "free": 171264, "percent": 12.5, "reserved": 512, "ratio": 1.5, "uniform_ratio": True},
                                  "local_gb": {"capacity": 1800, "used": 300, "free": 1500, "percent": 16.7, "reserved": 0, "ratio": 1.0, "uniform_ratio": True}}},
        "projects": [{"id": "p1", "name": "platform", "instances": 2, "active": 2, "vcpus": 8, "ram_mb": 16384, "disk_gb": 160,
                      "quota": {"available": True, "exceeded": [], "near_limit": ["vcpus"], "worst_percent": 88.0,
                                "resources": {"instances": {"label": "인스턴스", "used": 2, "limit": 10, "percent": 20.0, "unlimited": False, "estimated": False},
                                              "vcpus": {"label": "vCPU", "used": 88, "limit": 100, "percent": 88.0, "unlimited": False, "estimated": False},
                                              "ram_mb": {"label": "메모리", "used": 16384, "limit": 51200, "percent": 32.0, "unlimited": False, "estimated": False},
                                              "disk_gb": {"label": "볼륨 용량", "used": 160, "limit": -1, "percent": None, "unlimited": True, "estimated": False},
                                              "floating_ips": {"label": "Floating IP", "used": 3, "limit": 50, "percent": 6.0, "unlimited": False, "estimated": False}}}},
                     {"id": "p2", "name": "database", "instances": 1, "active": 0, "vcpus": 1, "ram_mb": 2048, "disk_gb": 20,
                      "quota": {"available": True, "exceeded": ["instances"], "near_limit": [], "worst_percent": 100.0,
                                "resources": {"instances": {"label": "인스턴스", "used": 5, "limit": 5, "percent": 100.0, "unlimited": False, "estimated": False}}}}],
        "instances": {"total": 3, "by_status": {"ACTIVE": 2, "ERROR": 1}},
        "quota_available": True,
        "zones": [{"name": "az-a", "hypervisors": 1, "hypervisors_up": 1, "instances": 3, "vcpus": 32, "vcpus_used": 12, "memory_mb": 131072,
                   "memory_mb_used": 24576, "local_gb": 1800, "local_gb_used": 300, "vcpu_capacity": 512, "vcpu_allocated": 12,
                   "vcpu_percent": 37.5, "vcpu_overcommit_percent": 2.3},
                  {"name": "az-b", "hypervisors": 1, "hypervisors_up": 0, "instances": 0, "vcpus": 32, "vcpus_used": 0, "memory_mb": 131072,
                   "memory_mb_used": 0, "local_gb": 1800, "local_gb_used": 0, "vcpu_capacity": 0, "vcpu_allocated": 0,
                   "vcpu_percent": 0.0, "vcpu_overcommit_percent": None}],
        "headroom": {"flavors": [{"name": "m1.large", "vcpus": 4, "ram_mb": 8192, "disk_gb": 80}],
                     "results": [{"name": "m1.large", "vcpus": 4, "ram_mb": 8192, "disk_gb": 80, "fits": 18, "limited_by": "disk"}]},
    }
    body = {"summary": {"nodes": 2, "reachable": 2, "openstack_available": True, "hypervisors": 2, "instances": 3, "volumes": 1, "networks": 2, "storage_backend": "ceph"},
            "controller": {"hostname": "hcon03", "target": "10.0.0.9", "error": ""},
            "nodes": [], "capacity": capacity,
            "openstack": {"available": True, "openrc": "/root/contrabass-openrc", "errors": {}, "hypervisors": [], "servers": [], "volumes": [], "networks": [], "projects": [], "flavors": []},
            "storage": {"backend": "none", "ceph": None, "nfs": {"mounts": [], "glance_on_nfs": False, "cinder_on_nfs": False, "cinder_mount_dirs": []}}}
    for key, value in overrides.items():
        if key == "capacity":
            body["capacity"].update(value)
        else:
            body[key] = value
    return body


def render(context: quickjs.Context, body: dict) -> None:
    inventory = {"status": "healthy", "collected_at": "2026-09-04T01:00:00+00:00", "duration_seconds": 12, "payload": body}
    # currentInventory is what the panel re-reads when a control changes, so set it the way loadInventory does.
    context.eval(f"globalThis.__lastPayload = {json.dumps(body)}; currentInventory = {json.dumps(inventory)}; renderInventory(currentInventory)")


@pytest.fixture()
def context() -> quickjs.Context:
    return make_context()


def test_overcommit_basis_switches_denominator(context):
    render(context, payload())
    html = context.eval("__html('#hypervisorCapacity')")
    assert "오버커밋 반영" in html and "×16" in html, "the default basis must show the placement ratio"
    assert "/ 512" in html, "vCPU must be shown against the overcommitted capacity, not the 32 physical cores"
    assert not context.eval("__hidden('#capacityBasis')"), "the toggle appears once any hypervisor has an allocation source"
    context.eval("capacityBasis = 'physical'; renderHypervisorCapacity(__lastPayload)")
    physical = context.eval("__html('#hypervisorCapacity')")
    assert "물리" in physical and "/ 512" not in physical, "physical basis must drop the overcommitted capacity"


def test_headroom_and_zone_tables_are_rendered(context):
    render(context, payload())
    html = context.eval("__html('#hypervisorCapacity')")
    assert "Flavor별 배치 여유" in html and "m1.large" in html and "18개" in html
    assert "디스크" in html, "the limiting resource is named so the operator knows what to add"
    assert "가용 영역별 용량" in html and "az-a" in html and "az-b" in html


def test_capacity_without_allocation_falls_back_to_physical(context):
    body = payload()
    body["capacity"]["hypervisors"] = [hypervisor("hcom01"), hypervisor("hcom02", state="down")]
    body["capacity"]["totals"]["overcommit"] = {"source": "", "mixed": False, "known_hypervisors": 0,
                                                "vcpus": {"capacity": 0, "used": 0, "free": 0, "percent": None, "reserved": 0, "ratio": None, "uniform_ratio": False},
                                                "memory_mb": {"capacity": 0, "used": 0, "free": 0, "percent": None, "reserved": 0, "ratio": None, "uniform_ratio": False},
                                                "local_gb": {"capacity": 0, "used": 0, "free": 0, "percent": None, "reserved": 0, "ratio": None, "uniform_ratio": False}}
    body["capacity"]["headroom"]["results"] = [{"name": "m1.large", "vcpus": 4, "ram_mb": 8192, "disk_gb": 80, "fits": None, "limited_by": ""}]
    render(context, body)
    html = context.eval("__html('#hypervisorCapacity')")
    assert context.eval("__hidden('#capacityBasis')"), "no allocation source anywhere means no basis to choose between"
    assert "오버커밋 비율을 읽지 못해" in html and "Flavor별 배치 여유" not in html
    assert "미수집" in html, "the ratio column says so rather than showing a made-up 1.0"


def test_project_quota_columns_and_states(context):
    render(context, payload())
    html = context.eval("__html('#projectUsage')")
    assert "vCPU 쿼터" in html and "88 / 100" in html and "무제한" in html
    assert "쿼터 초과" in html and "쿼터 임박" in html
    assert "쿼터 초과 1 · 임박 1" in context.eval("__text('#projectUsageMeta')")


def test_project_panel_without_quota_keeps_the_old_columns(context):
    body = payload()
    body["capacity"]["quota_available"] = False
    for project in body["capacity"]["projects"]:
        project["quota"] = {"available": False, "exceeded": [], "near_limit": [], "worst_percent": None, "resources": {}}
    render(context, body)
    html = context.eval("__html('#projectUsage')")
    assert "vCPU 비중" in html and "vCPU 쿼터" not in html
    assert "쿼터를 수집하지 못해" in html
    assert context.eval("__hidden('#projectUsageQuotaFilter')"), "the quota-only filter is meaningless without quota"


def test_project_sort_and_quota_filter(context):
    render(context, payload())
    context.eval("__set('#projectUsageSort', 'value', 'quota'); renderProjectUsage(__lastPayload)")
    rows = context.eval("__html('#projectUsage')")
    assert rows.index("database") < rows.index("platform"), "sorting by quota puts the exceeded project first"
    context.eval("__set('#projectUsageOnlyQuota', 'checked', true); renderProjectUsage(__lastPayload)")
    filtered = context.eval("__html('#projectUsage')")
    assert "database" in filtered and "platform" in filtered, "both projects are at or above 80%"
    body = payload()
    body["capacity"]["projects"][0]["quota"] = {"available": True, "exceeded": [], "near_limit": [], "worst_percent": 10.0, "resources": {}}
    render(context, body)
    context.eval("__set('#projectUsageOnlyQuota', 'checked', true); renderProjectUsage(__lastPayload)")
    assert "platform" not in context.eval("__html('#projectUsage')"), "a project well below the limit is filtered out"
