"""The runtime bundle installs a container runtime, so unlike the platform bundle it changes
the server. What matters is that it refuses to change a server that already has a runtime, that
it records everything it did so uninstall can undo exactly that, and that it never lays a
container bridge over a subnet the server already routes to.

These run the real deploy/runtime/*.sh in a POSIX shell against fake system tools, so the
behaviour under test is the shipped code rather than a description of it.
"""
from __future__ import annotations

import shutil
import subprocess
import tarfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "deploy" / "runtime"

# Every system tool the scripts reach for, replaced by a recorder. `ip route` output is the one
# that varies per test, so it comes from the environment.
FAKE_TOOLS = {
    "systemctl": '#!/bin/sh\nprintf "systemctl %s\\n" "$*" >> "$FAKE_LOG"\nexit 0\n',
    "sysctl": '#!/bin/sh\nprintf "sysctl %s\\n" "$*" >> "$FAKE_LOG"\nexit 0\n',
    "modprobe": '#!/bin/sh\nexit 0\n',
    "iptables": '#!/bin/sh\nexit 0\n',
    "ip": '#!/bin/sh\nprintf "%s\\n" "${FAKE_ROUTES:-}"\n',
}

# The binaries the tarball unpacks. `nerdctl info` succeeding is what the script waits for.
FAKE_NERDCTL = '#!/bin/sh\ncase "$1" in info) exit 0 ;; --version) echo "nerdctl version 9.9.9" ;; esac\nexit 0\n'
FAKE_CONTAINERD = '#!/bin/sh\necho "containerd github.com/containerd/containerd v9.9.9 abc"\n'
FAKE_RUNC = '#!/bin/sh\necho "runc version 9.9.9"\n'

CONTAINERD_UNIT = "[Unit]\nDescription=containerd\n[Service]\nExecStart=/usr/local/bin/containerd\n"


def _make_runtime_archive(path: Path) -> None:
    """A miniature nerdctl-full tarball with the same layout as the real one."""
    staging = path.parent / "staging"
    for rel, body, mode in (
        ("bin/nerdctl", FAKE_NERDCTL, 0o755),
        ("bin/containerd", FAKE_CONTAINERD, 0o755),
        ("bin/runc", FAKE_RUNC, 0o755),
        ("libexec/cni/bridge", "#!/bin/sh\n", 0o755),
        ("lib/systemd/system/containerd.service", CONTAINERD_UNIT, 0o644),
    ):
        target = staging / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
        target.chmod(mode)
    with tarfile.open(path, "w:gz") as tar:
        for item in sorted(staging.rglob("*")):
            tar.add(item, arcname=str(item.relative_to(staging)))
    shutil.rmtree(staging)


@pytest.fixture()
def bundle(tmp_path: Path) -> Path:
    """A runtime bundle laid out the way build-runtime-bundle.sh produces it."""
    for name in ("install-runtime.sh", "uninstall-runtime.sh"):
        shutil.copy(RUNTIME_DIR / name, tmp_path / name)
        (tmp_path / name).chmod(0o755)

    archive = tmp_path / "nerdctl-full-9.9.9-linux-amd64.tar.gz"
    _make_runtime_archive(archive)
    digest = subprocess.run(["sha256sum", archive.name], cwd=tmp_path, capture_output=True, text=True).stdout
    (tmp_path / "SHA256SUMS").write_text(digest)

    fake_bin = tmp_path / "fakebin"
    fake_bin.mkdir()
    for name, body in FAKE_TOOLS.items():
        (fake_bin / name).write_text(body)
        (fake_bin / name).chmod(0o755)
    return tmp_path


def install(
    bundle: Path,
    *args: str,
    routes: str = "",
    ip_forward: str = "1",
    bridge_nf: str | None = "1",
    **env,
) -> subprocess.CompletedProcess:
    """Run the real install-runtime.sh with system paths pointed at the sandbox.

    `bridge_nf=None` stands for a kernel without br_netfilter: the proc file is simply absent.
    """
    forward = bundle / "ip_forward"
    forward.write_text(ip_forward)
    bridge_nf_path = bundle / "bridge_nf"
    if bridge_nf is None:
        bridge_nf_path.unlink(missing_ok=True)
    else:
        bridge_nf_path.write_text(bridge_nf)
    environment = {
        # Only the fake tools are on PATH, so `command -v docker` finds nothing: a clean server.
        "PATH": f"{bundle / 'fakebin'}:/usr/bin:/bin",
        "FAKE_LOG": str(bundle / "calls.log"),
        "FAKE_ROUTES": routes,
        "OPS_UNIT_DIR": str(bundle / "etc-systemd"),
        "OPS_CNI_CONF_DIR": str(bundle / "etc-cni"),
        "OPS_IP_FORWARD_PATH": str(forward),
        "OPS_BRIDGE_NF_PATH": str(bridge_nf_path),
        "OPS_SYSCTL_DIR": str(bundle / "etc-sysctl.d"),
        "OPS_MODULES_DIR": str(bundle / "etc-modules-load.d"),
        **{k: str(v) for k, v in env.items()},
    }
    (bundle / "etc-systemd").mkdir(exist_ok=True)
    return subprocess.run(
        ["/bin/sh", str(bundle / "install-runtime.sh"), "--prefix", str(bundle / "prefix"), *args],
        capture_output=True, text=True, env=environment,
    )


def uninstall(bundle: Path, *args: str) -> subprocess.CompletedProcess:
    environment = {"PATH": f"{bundle / 'fakebin'}:/usr/bin:/bin", "FAKE_LOG": str(bundle / "calls.log")}
    return subprocess.run(
        ["/bin/sh", str(bundle / "uninstall-runtime.sh"), *args],
        capture_output=True, text=True, env=environment,
    )


# --- a clean server ---------------------------------------------------------------------------

def test_install_lays_down_binaries_unit_and_cni_config(bundle: Path):
    result = install(bundle, routes="default via 10.255.191.254 dev ens3\n10.255.191.0/24 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr

    assert (bundle / "prefix" / "bin" / "nerdctl").exists()
    assert (bundle / "prefix" / "libexec" / "cni" / "bridge").exists()
    assert (bundle / "etc-systemd" / "containerd.service").exists(), "the unit must land where systemd reads it"
    assert (bundle / "etc-cni" / "nerdctl-bridge.conflist").exists()
    assert "containerd v9.9.9" in result.stdout and "nerdctl 9.9.9" in result.stdout


def test_manifest_records_every_file_so_uninstall_can_undo_it(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3")
    manifest = (bundle / "installed-manifest.txt").read_text()

    for expected in ("bin/nerdctl", "bin/containerd", "libexec/cni/bridge", "containerd.service", "nerdctl-bridge.conflist"):
        assert expected in manifest, f"{expected} is installed but not recorded, so uninstall would leave it"
    assert "SERVICE=containerd" in manifest


def test_uninstall_removes_exactly_what_the_manifest_lists(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3")
    stranger = bundle / "prefix" / "bin" / "somebody-elses-tool"
    stranger.write_text("#!/bin/sh\n")

    result = uninstall(bundle)
    assert result.returncode == 0, result.stdout + result.stderr
    assert not (bundle / "prefix" / "bin" / "nerdctl").exists()
    assert not (bundle / "etc-systemd" / "containerd.service").exists()
    assert stranger.exists(), "uninstall must not touch files it did not install"
    assert (bundle / "installed-manifest.txt.removed").exists()


# --- a server that already has a runtime -------------------------------------------------------

def test_existing_runtime_stops_the_install(bundle: Path):
    (bundle / "fakebin" / "docker").write_text("#!/bin/sh\nexit 0\n")
    (bundle / "fakebin" / "docker").chmod(0o755)

    result = install(bundle, routes="10.255.191.0/24 dev ens3")
    assert result.returncode != 0
    assert "이미 컨테이너 런타임이 있습니다" in result.stderr
    assert not (bundle / "prefix").exists(), "nothing may be written when we refuse"


def test_force_overrides_the_existing_runtime_guard(bundle: Path):
    (bundle / "fakebin" / "podman").write_text("#!/bin/sh\nexit 0\n")
    (bundle / "fakebin" / "podman").chmod(0o755)

    result = install(bundle, "--force", routes="10.255.191.0/24 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr
    assert (bundle / "prefix" / "bin" / "nerdctl").exists()


def test_existing_files_at_the_prefix_are_not_overwritten(bundle: Path):
    occupied = bundle / "prefix" / "bin" / "nerdctl"
    occupied.parent.mkdir(parents=True)
    occupied.write_text("#!/bin/sh\necho somebody else\n")

    result = install(bundle, routes="10.255.191.0/24 dev ens3")
    assert result.returncode != 0
    assert "덮어쓰지 않고 중단" in result.stderr
    assert "somebody else" in occupied.read_text()


# --- the bridge subnet ------------------------------------------------------------------------

@pytest.mark.parametrize("routes", [
    "10.4.0.0/24 dev br0",                      # exactly the default bridge range
    "10.0.0.0/8 via 10.1.2.3 dev ens3",         # the site routes all of 10/8
    "10.4.0.128/25 dev ens4",                   # a slice inside the default range
])
def test_bridge_subnet_that_the_server_already_routes_stops_the_install(bundle: Path, routes: str):
    result = install(bundle, routes=routes)
    assert result.returncode != 0, "a bridge over a routed subnet silently breaks node access"
    assert "겹칩니다" in result.stderr
    assert not (bundle / "etc-cni" / "nerdctl-bridge.conflist").exists()


def test_a_free_subnet_can_be_chosen_when_the_default_collides(bundle: Path):
    result = install(bundle, "--cni-subnet", "172.31.240.0/24", routes="10.0.0.0/8 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr
    conflist = (bundle / "etc-cni" / "nerdctl-bridge.conflist").read_text()
    assert '"subnet": "172.31.240.0/24"' in conflist
    assert '"gateway": "172.31.240.1"' in conflist


def test_default_route_alone_is_not_a_collision(bundle: Path):
    # `default via ...` has no prefix to compare. Treating it as a collision would block every server.
    result = install(bundle, routes="default via 10.255.191.254 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr


def test_no_bridge_skips_network_setup_entirely(bundle: Path):
    result = install(bundle, "--no-bridge", routes="10.0.0.0/8 dev ens3")
    assert result.returncode == 0, "host-network deployments must not be blocked by a subnet collision"
    assert not (bundle / "etc-cni" / "nerdctl-bridge.conflist").exists()
    assert "USE_HOST_NETWORK=yes" in result.stdout


# --- the one kernel setting it changes ---------------------------------------------------------

def test_ip_forward_is_left_alone_when_already_on(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3", ip_forward="1")
    assert "SYSCTL_IP_FORWARD_WAS" not in (bundle / "installed-manifest.txt").read_text()
    assert "sysctl -w net.ipv4.ip_forward" not in (bundle / "calls.log").read_text()


def test_ip_forward_is_turned_on_and_recorded_when_it_was_off(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3", ip_forward="0")
    assert "SYSCTL_IP_FORWARD_WAS=0" in (bundle / "installed-manifest.txt").read_text()
    assert "net.ipv4.ip_forward=1" in (bundle / "calls.log").read_text()

    uninstall(bundle)
    assert "net.ipv4.ip_forward=0" in (bundle / "calls.log").read_text(), "what we switched on must be switched back"


def test_bridge_netfilter_is_turned_on_and_recorded_when_it_was_off(bundle: Path):
    # Without this the portmap DNAT never fires and the published port silently drops traffic.
    install(bundle, routes="10.255.191.0/24 dev ens3", bridge_nf="0")
    assert "SYSCTL_BRIDGE_NF_WAS=0" in (bundle / "installed-manifest.txt").read_text()
    assert "net.bridge.bridge-nf-call-iptables=1" in (bundle / "calls.log").read_text()

    uninstall(bundle)
    assert "net.bridge.bridge-nf-call-iptables=0" in (bundle / "calls.log").read_text()


def test_bridge_netfilter_is_left_alone_when_already_on(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3", bridge_nf="1")
    assert "SYSCTL_BRIDGE_NF_WAS" not in (bundle / "installed-manifest.txt").read_text()
    assert "bridge-nf-call-iptables=1" not in (bundle / "calls.log").read_text()


def test_a_kernel_without_br_netfilter_warns_but_installs(bundle: Path):
    result = install(bundle, routes="10.255.191.0/24 dev ens3", bridge_nf=None)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "br_netfilter" in result.stderr


# --- surviving a reboot -----------------------------------------------------------------------

def test_kernel_settings_are_persisted_and_removed_again(bundle: Path):
    # A runtime that only works until the next reboot is the worst kind: the container comes back
    # and the inspections do not.
    install(bundle, routes="10.255.191.0/24 dev ens3", ip_forward="0")
    modules = bundle / "etc-modules-load.d" / "openstack-ops-runtime.conf"
    sysctl = bundle / "etc-sysctl.d" / "99-openstack-ops-runtime.conf"

    assert "overlay" in modules.read_text() and "br_netfilter" in modules.read_text()
    assert "net.ipv4.ip_forward = 1" in sysctl.read_text()
    assert "net.bridge.bridge-nf-call-iptables = 1" in sysctl.read_text()

    manifest = (bundle / "installed-manifest.txt").read_text()
    assert str(modules) in manifest and str(sysctl) in manifest

    uninstall(bundle)
    assert not modules.exists() and not sysctl.exists(), "system config we added must go with us"


def test_no_persist_leaves_no_system_config_behind(bundle: Path):
    install(bundle, "--no-persist", routes="10.255.191.0/24 dev ens3")
    assert not (bundle / "etc-modules-load.d").exists()
    assert not (bundle / "etc-sysctl.d").exists()


def test_no_bridge_persists_the_module_but_not_the_network_sysctls(bundle: Path):
    # overlay is needed for the snapshotter either way; the bridge settings are not.
    install(bundle, "--no-bridge", routes="10.255.191.0/24 dev ens3")
    modules = (bundle / "etc-modules-load.d" / "openstack-ops-runtime.conf").read_text()
    assert "overlay" in modules and "br_netfilter" not in modules
    assert not (bundle / "etc-sysctl.d").exists()


# --- a server missing the tools the bridge needs -----------------------------------------------

def test_missing_iptables_stops_a_bridge_install(bundle: Path):
    (bundle / "fakebin" / "iptables").unlink()

    result = install(bundle, routes="10.255.191.0/24 dev ens3")
    assert result.returncode != 0
    assert "iptables 가 없습니다" in result.stderr
    assert "USE_HOST_NETWORK=yes" in result.stderr, "the operator needs the way out, not just the refusal"
    assert not (bundle / "prefix").exists()


def test_missing_iptables_does_not_stop_a_host_network_install(bundle: Path):
    (bundle / "fakebin" / "iptables").unlink()

    result = install(bundle, "--no-bridge", routes="10.255.191.0/24 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr


def test_force_installs_without_iptables(bundle: Path):
    (bundle / "fakebin" / "iptables").unlink()

    result = install(bundle, "--force", routes="10.255.191.0/24 dev ens3")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "브리지 네트워크는 동작하지 않습니다" in result.stderr


# --- integrity --------------------------------------------------------------------------------

def test_a_corrupted_archive_stops_the_install(bundle: Path):
    archive = bundle / "nerdctl-full-9.9.9-linux-amd64.tar.gz"
    archive.write_bytes(archive.read_bytes() + b"tampered")

    result = install(bundle, routes="10.255.191.0/24 dev ens3")
    assert result.returncode != 0
    assert "체크섬이 맞지 않습니다" in result.stderr
    assert not (bundle / "prefix").exists()


def test_uninstall_without_a_manifest_does_nothing(bundle: Path):
    result = uninstall(bundle)
    assert result.returncode != 0
    assert "설치 기록이 없습니다" in result.stderr


def test_uninstall_refuses_while_containers_are_running(bundle: Path):
    install(bundle, routes="10.255.191.0/24 dev ens3")
    # A runtime that reports one running container in one namespace.
    (bundle / "prefix" / "bin" / "nerdctl").write_text(
        '#!/bin/sh\ncase "$*" in\n  info) exit 0 ;;\n  *"namespace ls"*) echo openstack-ops ;;\n'
        '  *ps*) echo "[openstack-ops-platform]" ;;\nesac\nexit 0\n'
    )
    (bundle / "prefix" / "bin" / "nerdctl").chmod(0o755)

    result = uninstall(bundle)
    assert result.returncode != 0
    assert "돌고 있는 컨테이너가 있습니다" in result.stderr
    assert (bundle / "prefix" / "bin" / "containerd").exists(), "nothing may be removed when we refuse"
