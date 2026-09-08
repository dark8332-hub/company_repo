"""The offline bundle must not disturb the deploy server it is unpacked on.

These run the real deploy/lib.sh in a POSIX shell against a fake container runtime, so the
behaviour under test is the shipped code rather than a description of it. What matters on a
shared deploy server: the port check looks at the port actually taken, an existing container
that belongs to somebody else is never force-removed, and nothing is written outside the bundle.
"""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = ROOT / "deploy"

# `docker ps` output the fake runtime replays, keyed by the arguments the scripts pass.
FAKE_RUNTIME = """#!/bin/sh
# Fake container runtime. Records every invocation and replays canned `ps` output.
printf '%s\\n' "$*" >> "$FAKE_LOG"
case "$1" in
  info) exit 0 ;;
  ps)
    case "$*" in
      *Ports*)    printf '%s\\n' "${FAKE_PS_PORTS:-}" ;;
      *--filter*) printf '%s\\n' "${FAKE_PS_IMAGE:-}" ;;
      *-a*)       printf '%s\\n' "${FAKE_PS_ALL:-}" ;;
      *)          printf '%s\\n' "${FAKE_PS_RUNNING:-}" ;;
    esac ;;
esac
exit 0
"""


@pytest.fixture()
def bundle(tmp_path: Path) -> Path:
    """A bundle directory laid out the way build-offline-bundle.sh produces it."""
    for name in ("lib.sh", "install.sh", "opsctl.sh"):
        shutil.copy(DEPLOY / name, tmp_path / name)
        (tmp_path / name).chmod(0o755)
    (tmp_path / "config.env").write_text("IMAGE_TAG=1.0.0\nHOST_PORT=8090\nCONTAINER_NAME=openstack-ops-platform\n")
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    (fake_bin / "docker").write_text(FAKE_RUNTIME)
    (fake_bin / "docker").chmod(0o755)
    return tmp_path


def run_lib(bundle: Path, script: str, **env) -> subprocess.CompletedProcess:
    """Source lib.sh with the fake runtime on PATH and run `script`."""
    body = f'. "{bundle}/lib.sh"\ndetect_runtime\nload_config\n{script}\n'
    (bundle / "case.sh").write_text(body)
    environment = {"PATH": f"{bundle / 'bin'}:/usr/bin:/bin", "FAKE_LOG": str(bundle / "calls.log"), **{k: str(v) for k, v in env.items()}}
    return subprocess.run(["/bin/sh", str(bundle / "case.sh")], capture_output=True, text=True, env=environment)


# --- the port that is actually taken -------------------------------------------------------

def test_effective_port_follows_host_network_mode(bundle: Path):
    assert run_lib(bundle, "effective_port").stdout == "8090"
    (bundle / "config.env").write_text("IMAGE_TAG=1.0.0\nHOST_PORT=9000\nCONTAINER_NAME=x\n")
    assert run_lib(bundle, "effective_port").stdout == "9000", "bridge mode publishes HOST_PORT"
    (bundle / "config.env").write_text("IMAGE_TAG=1.0.0\nHOST_PORT=9000\nUSE_HOST_NETWORK=yes\nCONTAINER_NAME=x\n")
    assert run_lib(bundle, "effective_port").stdout == "8090", "host network ignores HOST_PORT and takes 8090"


def test_install_checks_the_effective_port_not_the_configured_one(bundle: Path):
    install = (DEPLOY / "install.sh").read_text()
    assert re.search(r'check_port="\$\(effective_port\)"', install), "install.sh must derive the port from effective_port()"
    assert 'port_in_use "$check_port"' in install, "the listener check must use that port"
    assert "$HOST_PORT\\$" not in install, "checking HOST_PORT misses host-network mode"


# --- never remove a container that is not ours ---------------------------------------------

def test_foreign_container_with_the_same_name_is_not_ours(bundle: Path):
    # `command -v` first: without it a missing function would fall through to the || branch and
    # this test would pass on a build that has no ownership check at all.
    exists = run_lib(bundle, "command -v container_is_ours >/dev/null && echo DEFINED || echo MISSING")
    assert exists.stdout.strip() == "DEFINED", "lib.sh must define container_is_ours"
    result = run_lib(bundle, "container_is_ours && echo OURS || echo FOREIGN", FAKE_PS_IMAGE="registry.local/other-team/api:3.1")
    assert result.stdout.strip() == "FOREIGN", result.stderr


def test_our_own_container_is_recognised(bundle: Path):
    for image in ("okestro/openstack-ops-platform:1.0.0", "docker.io/okestro/openstack-ops-platform:0.9"):
        result = run_lib(bundle, "container_is_ours && echo OURS || echo FOREIGN", FAKE_PS_IMAGE=image)
        assert result.stdout.strip() == "OURS", (image, result.stderr)


def test_unknown_image_keeps_the_reinstall_path(bundle: Path):
    """A runtime that cannot print the image must not block a legitimate reinstall."""
    result = run_lib(bundle, "container_is_ours && echo OURS || echo FOREIGN", FAKE_PS_IMAGE="")
    assert result.stdout.strip() == "OURS", result.stderr


def test_install_refuses_before_removing_a_foreign_container():
    install = (DEPLOY / "install.sh").read_text()
    guard = install.index("container_is_ours || die")
    removal = install.index('rt rm -f "$CONTAINER_NAME"')
    assert guard < removal, "the ownership check must come before the force removal"


# --- nerdctl name output, still the same for the new helper ---------------------------------

def test_container_names_strips_nerdctl_brackets(bundle: Path):
    result = run_lib(bundle, 'container_names -a', FAKE_PS_ALL="[openstack-ops-platform]")
    assert result.stdout.split() == ["openstack-ops-platform"]
    result = run_lib(bundle, 'container_exists && echo YES || echo NO', FAKE_PS_ALL="[openstack-ops-platform]")
    assert result.stdout.strip() == "YES"


# --- a failed start must not be reported as success ------------------------------------------

def test_wait_healthy_fails_when_our_container_is_not_running(bundle: Path):
    """The health probe used to curl the host port, so another service listening on it answered
    for us: a container that could not bind the port was reported as a successful install."""
    dead = run_lib(bundle, "wait_healthy 1 && echo HEALTHY || echo DOWN", FAKE_PS_RUNNING="")
    assert dead.stdout.strip() == "DOWN", dead.stderr
    alive = run_lib(bundle, "wait_healthy 1 && echo HEALTHY || echo DOWN", FAKE_PS_RUNNING="openstack-ops-platform")
    assert alive.stdout.strip() == "HEALTHY", alive.stderr


def test_wait_healthy_probes_inside_the_container(bundle: Path):
    run_lib(bundle, "wait_healthy 1 || true", FAKE_PS_RUNNING="openstack-ops-platform")
    calls = (bundle / "calls.log").read_text()
    assert "exec openstack-ops-platform python" in calls, "the probe must run inside the container"
    assert "curl" not in (DEPLOY / "lib.sh").read_text().split("wait_healthy()")[1].split("\n}")[0], \
        "wait_healthy must not fall back to curling the host port"


def test_failed_start_stops_the_container(bundle: Path):
    """Left alone, `--restart unless-stopped` turns a failed start into a permanent restart loop
    on the deploy server."""
    result = run_lib(bundle, "stop_failed_container")
    assert result.returncode == 0, result.stderr
    assert "stop openstack-ops-platform" in (bundle / "calls.log").read_text()
    install = (DEPLOY / "install.sh").read_text()
    assert install.index("stop_failed_container") < install.index('die "기동 실패'), \
        "install.sh must stop the container before giving up"
    opsctl = (DEPLOY / "opsctl.sh").read_text()
    assert opsctl.count("stop_failed_container") == 3, "start, restart and restore all need it"


def test_install_rechecks_the_port_after_removing_its_own_container():
    """The early check exempts a running instance of ours, so the decisive check has to happen
    once that instance is gone - otherwise a reinstall walks straight into somebody else's port."""
    install = (DEPLOY / "install.sh").read_text()
    removal = install.index('rt rm -f "$CONTAINER_NAME"')
    recheck = install.index('if port_in_use "$check_port"; then', removal)
    start = install.index("\nstart_container", removal)
    assert removal < recheck < start, "the port re-check belongs between the removal and the start"


# 65432 throughout: high enough that no real listener on the test host answers, so the verdict
# comes from the fake runtime rather than from `ss`.
def test_port_in_use_sees_a_port_published_by_another_container(bundle: Path):
    """nerdctl/CNI maps ports with iptables DNAT, so a published port has no LISTEN socket and
    `ss` cannot see it. Checking `ss` alone let a second container claim a port another one
    already held: both got DNAT rules and requests went to whichever matched first."""
    busy = run_lib(bundle, "port_in_use 65432 && echo BUSY || echo FREE", FAKE_PS_PORTS="0.0.0.0:65432->8090/tcp")
    assert busy.stdout.strip() == "BUSY", busy.stderr
    free = run_lib(bundle, "port_in_use 65432 && echo BUSY || echo FREE", FAKE_PS_PORTS="0.0.0.0:8091->8090/tcp")
    assert free.stdout.strip() == "FREE", free.stderr


def test_port_in_use_handles_nerdctl_bracket_output(bundle: Path):
    busy = run_lib(bundle, "port_in_use 65432 && echo BUSY || echo FREE", FAKE_PS_PORTS="[0.0.0.0:65432->8090/tcp]")
    assert busy.stdout.strip() == "BUSY", busy.stderr


def test_port_in_use_does_not_match_the_container_side_of_a_mapping(bundle: Path):
    """`0.0.0.0:8097->65432/tcp` publishes 8097, not 65432; matching the right-hand side would
    refuse installs over a port nobody holds on the host."""
    free = run_lib(bundle, "port_in_use 65432 && echo BUSY || echo FREE", FAKE_PS_PORTS="0.0.0.0:8097->65432/tcp")
    assert free.stdout.strip() == "FREE", free.stderr


def test_port_in_use_ignores_stopped_containers(bundle: Path):
    """A stopped container holds no port, so only `ps` (running) may answer this."""
    run_lib(bundle, "port_in_use 65432 || true", FAKE_PS_PORTS="0.0.0.0:65432->8090/tcp")
    calls = (bundle / "calls.log").read_text()
    assert "ps --format {{.Ports}}" in calls
    assert "ps -a --format {{.Ports}}" not in calls, "stopped containers must not count"


def test_config_is_written_before_the_port_check():
    """The operator's way out of a port clash is to edit config.env and re-run, so the file has to
    exist by the time the check refuses - a die before the copy would leave nothing to edit."""
    install = (DEPLOY / "install.sh").read_text()
    copied = install.index('cp "$BUNDLE_DIR/config.env.example" "$CONFIG_FILE"')
    first_check = install.index('if port_in_use "$check_port" && ! container_running; then')
    assert copied < first_check, "config.env must be created before the port check can abort"
    assert install.index("load_config") < first_check, "the check reads HOST_PORT from config.env"


# --- nothing outside the bundle -------------------------------------------------------------

WRITE = re.compile(r"(?:^|[|;&(]\s*)(?:mkdir|rm|cp|mv|tee|chmod|chown|touch|ln)\s+[^\n]*")
ABSOLUTE = re.compile(r"(?<![\w$/\"'])/(?:etc|usr|var|opt|srv|lib|bin|sbin|boot|root|home)\b")


@pytest.mark.parametrize("script", ["install.sh", "opsctl.sh", "lib.sh"])
def test_no_writes_to_system_paths(script: str):
    """Every write in the deploy scripts must land under the bundle directory."""
    for line in (DEPLOY / script).read_text().splitlines():
        code = line.split("#", 1)[0] if not line.lstrip().startswith("#") else ""
        for command in WRITE.findall(code):
            assert not ABSOLUTE.search(command), f"{script}: writes outside the bundle: {command.strip()}"


@pytest.mark.parametrize("script", ["install.sh", "opsctl.sh", "lib.sh"])
def test_no_package_installs_or_service_changes(script: str):
    """Installing packages or enabling services would change the deploy server itself."""
    for line in (DEPLOY / script).read_text().splitlines():
        code = line.split("#", 1)[0] if not line.lstrip().startswith("#") else ""
        if code.strip().startswith(("log ", "info ", "warn ", "die ", "ok ")) or '"' in code and "systemctl status" in code:
            continue
        assert not re.search(r"\b(?:yum|dnf|apt-get|apt|rpm|pip)\s+install\b", code), f"{script}: installs packages: {line.strip()}"
        assert not re.search(r"\bsystemctl\s+(?:enable|start|restart|daemon-reload)\b", code), f"{script}: changes host services: {line.strip()}"
        assert not re.search(r"\b(?:iptables|firewall-cmd|setenforce|sysctl)\b", code), f"{script}: changes host settings: {line.strip()}"


@pytest.mark.parametrize("script", ["install.sh", "opsctl.sh", "lib.sh"])
def test_scripts_are_posix_sh(script: str):
    assert subprocess.run(["/bin/sh", "-n", str(DEPLOY / script)]).returncode == 0


# --- netcheck: telling the operator which layer is blocking --------------------------------

# The probe reports its verdict on a NETCHECK= line rather than through an exit code, because
# `nerdctl exec` swallows the container command's status and exits 1 itself. These replay canned
# probe output so the mapping from verdict to advice is what is under test.
NETCHECK_RUNTIME = """#!/bin/sh
case "$1" in
  info) exit 0 ;;
  ps)   printf '%s\\n' "$FAKE_CONTAINER" ;;
  exec) cat "$FAKE_EXEC_OUT" ;;
esac
exit 0
"""

OK_PROBE = "  [OK] SSH 응답  SSH-2.0-OpenSSH_8.9p1\nNETCHECK=0\n"
DNS_PROBE = "  [!] 이름 해석 실패\nNETCHECK=2\n"
REFUSED_PROBE = "  [!] 연결 실패\nNETCHECK=3\n"
NOT_SSH_PROBE = "  [!] 열려 있지만 SSH 가 아닙니다\nNETCHECK=4\n"


def run_netcheck(bundle: Path, inside: str, on_host: str | None) -> str:
    """Run the real `opsctl.sh netcheck` with both probes replaced by canned output."""
    fake_bin = bundle / "bin"
    (fake_bin / "docker").write_text(NETCHECK_RUNTIME)
    (fake_bin / "docker").chmod(0o755)
    (bundle / "inside.txt").write_text(inside)

    if on_host is None:
        # A server without python3. `command -v python3` has to fail, so PATH gets only the
        # handful of tools the script itself needs - the real python3 must not be reachable.
        toolbox = bundle / "toolbox"
        toolbox.mkdir(exist_ok=True)
        for tool in ("awk", "grep", "sed", "cat", "rm", "tr", "head", "tail", "sh", "dirname", "pwd", "du", "hostname"):
            found = shutil.which(tool)
            if found and not (toolbox / tool).exists():
                (toolbox / tool).symlink_to(found)
        path = f"{fake_bin}:{toolbox}"
    else:
        (bundle / "host.txt").write_text(on_host)
        (fake_bin / "python3").write_text(f'#!/bin/sh\ncat "{bundle / "host.txt"}"\n')
        (fake_bin / "python3").chmod(0o755)
        path = f"{fake_bin}:/usr/bin:/bin"

    environment = {
        "PATH": path,
        "FAKE_LOG": str(bundle / "calls.log"),
        "FAKE_CONTAINER": "openstack-ops-platform",
        "FAKE_EXEC_OUT": str(bundle / "inside.txt"),
    }
    result = subprocess.run(
        ["/bin/sh", str(bundle / "opsctl.sh"), "netcheck", "10.255.191.11"],
        capture_output=True, text=True, env=environment,
    )
    return result.stdout + result.stderr


def test_netcheck_reports_success_when_both_sides_reach_the_node(bundle: Path):
    out = run_netcheck(bundle, OK_PROBE, OK_PROBE)
    assert "네트워크는 문제가 아닙니다" in out
    assert "USE_HOST_NETWORK" not in out, "no network change should be suggested when the path works"


def test_netcheck_points_at_the_bridge_when_only_the_container_is_blocked(bundle: Path):
    """The single most common deployment failure: the bridge cannot reach the private network."""
    out = run_netcheck(bundle, REFUSED_PROBE, OK_PROBE)
    assert "컨테이너에서만 막혔습니다" in out
    assert "USE_HOST_NETWORK=yes" in out


def test_netcheck_points_at_the_inventory_when_the_name_does_not_resolve(bundle: Path):
    out = run_netcheck(bundle, DNS_PROBE, DNS_PROBE)
    assert "이름 해석에서 막혔습니다" in out
    assert "노드 인벤토리" in out
    assert "USE_HOST_NETWORK" not in out, "host networking does not fix a name that resolves nowhere"


def test_netcheck_points_outside_the_server_when_neither_side_reaches(bundle: Path):
    out = run_netcheck(bundle, REFUSED_PROBE, REFUSED_PROBE)
    assert "경로가 없습니다" in out
    assert "USE_HOST_NETWORK" not in out, "host networking cannot fix a route that does not exist"


def test_netcheck_flags_a_port_that_is_open_but_not_ssh(bundle: Path):
    out = run_netcheck(bundle, NOT_SSH_PROBE, NOT_SSH_PROBE)
    assert "SSH 가 아닙니다" in out


def test_netcheck_still_reports_when_the_host_has_no_python(bundle: Path):
    out = run_netcheck(bundle, REFUSED_PROBE, None)
    assert "호스트 쪽은 확인하지 못했습니다" in out
    assert "ssh -p 22" in out, "the operator needs a command to run by hand"


def test_netcheck_does_not_depend_on_the_exec_exit_code(bundle: Path):
    """nerdctl exec exits 1 regardless of the command's status, so the verdict must come from output."""
    opsctl = (DEPLOY / "opsctl.sh").read_text()
    netcheck = opsctl[opsctl.index("netcheck)"):opsctl.index("backup)")]
    assert "NETCHECK=" in netcheck
    assert "|| in_rc=$?" not in netcheck, "reading the exec exit code misreads every result under nerdctl"


def test_netcheck_probe_does_not_need_tools_missing_from_the_image(bundle: Path):
    """The image is python:3.12-slim: no nc, ping, ssh or curl. Advice that uses them is useless."""
    opsctl = (DEPLOY / "opsctl.sh").read_text()
    netcheck = opsctl[opsctl.index("netcheck)"):opsctl.index("backup)")]
    for tool in ("nc ", "ncat ", "ping ", "telnet ", "curl "):
        assert f"rt exec -i \"$CONTAINER_NAME\" {tool}" not in netcheck
    assert 'rt exec -i "$CONTAINER_NAME" python' in netcheck
