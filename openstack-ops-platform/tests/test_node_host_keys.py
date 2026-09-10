"""Node connections must verify host keys without a file on the machine running this platform.

Every node connection - daily checks, inventory collection, custom checks - used to pass
`known_hosts="/root/.ssh/known_hosts"` to asyncssh. That works on the deploy server this was
written on, where somebody had run `ssh-keyscan` for all 28 hosts. It works nowhere else.

In a container the file does not exist, so `provider_ssh_options` plus a missing file means every
node fails with `HostKeyNotVerifiable` - after discovery has already succeeded, because discovery
talks to the VIP, which is pinned from the database instead. On a freshly built deploy server the
file is empty for the same reason. The platform looked installed and could not check a single node.

Host keys are now collected from the active controller during discovery and stored per provider,
the same place the controller's own key already lived. These tests hold that line: no hardcoded
path in a connection, and the trust decision comes from the database.
"""
from __future__ import annotations

import ast
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER = (ROOT / "server.py").read_text(encoding="utf-8")
TREE = ast.parse(SERVER)


def assignments_to_known_hosts() -> list[tuple[int, str]]:
    """Every `options["known_hosts"] = ...`, as (line, source of the right-hand side)."""
    found = []
    for node in ast.walk(TREE):
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if (isinstance(target, ast.Subscript) and isinstance(target.slice, ast.Constant)
                    and target.slice.value == "known_hosts"):
                found.append((node.lineno, ast.get_source_segment(SERVER, node.value) or ""))
    return found


def test_no_connection_reads_a_hardcoded_known_hosts_path():
    hardcoded = [(line, source) for line, source in assignments_to_known_hosts()
                 if re.search(r"""['"]/.*known_hosts['"]""", source)]
    assert not hardcoded, (
        f"server.py:{hardcoded[0][0]} pins host keys to a file path on this machine. "
        "A container has no such file and a new deploy server's is empty, so every node connection "
        "fails with HostKeyNotVerifiable. Use provider_known_hosts(provider_id)."
    )


def test_node_connections_verify_against_stored_keys():
    sources = [source for _, source in assignments_to_known_hosts()]
    assert any("provider_known_hosts" in source for source in sources), \
        "No connection builds its known_hosts from the provider's stored keys."


def test_no_connection_disables_host_key_checking():
    """`known_hosts=None` tells asyncssh to accept any key. It must never reach a real connection."""
    disabled = [line for line, source in assignments_to_known_hosts() if source.strip() == "None"]
    assert not disabled, (
        f"server.py:{disabled[0]} sets known_hosts=None, which accepts any host key and makes the "
        "connection trivially interceptable."
    )


def test_provider_ssh_options_leaves_verification_to_the_caller():
    """The shared options helper starts unverified on purpose; callers must set the policy."""
    match = re.search(r"def provider_ssh_options.*?\n(?=\n\S|\nclass )", SERVER, re.S)
    assert match, "provider_ssh_options not found."
    assert '"known_hosts": None' in match.group(0), (
        "provider_ssh_options no longer defaults known_hosts; if it now carries a policy of its "
        "own, this test and the callers that override it need revisiting together."
    )


def test_discovery_collects_node_host_keys():
    assert "ssh-keyscan" in SERVER, \
        "The discovery script no longer collects node host keys from the controller."
    assert "def store_discovered_host_keys" in SERVER, \
        "Discovered host keys are not stored, so node connections have nothing to verify against."


def test_stored_keys_survive_a_round_trip(tmp_path, monkeypatch):
    """A key written by discovery must come back in a form asyncssh can pin a connection to."""
    monkeypatch.setenv("APP_DATA_DIR", str(tmp_path))
    import importlib

    import asyncssh
    import provider_store
    importlib.reload(provider_store)

    key = asyncssh.generate_private_key("ssh-ed25519")
    public_text = key.export_public_key().decode().strip()
    fingerprint = asyncssh.import_public_key(public_text).get_fingerprint("sha256")

    provider_store.trust_provider_host_key("p1", fingerprint, "hcom01", "10.0.0.9",
                                           public_key=public_text, role="compute")

    material = provider_store.provider_host_key_material("p1")
    assert material == [public_text]
    assert asyncssh.import_public_key(material[0]).get_fingerprint("sha256") == fingerprint

    stored = provider_store.list_provider_host_keys("p1")[0]
    assert (stored["hostname"], stored["address"], stored["role"]) == ("hcom01", "10.0.0.9", "compute")

    importlib.reload(provider_store)


def test_legacy_known_hosts_is_only_a_fallback():
    """Falling back to the file keeps existing installs working - but only when nothing is stored."""
    match = re.search(r"def provider_known_hosts.*?\n(?=\n\S|\nclass |\n@)", SERVER, re.S)
    assert match, "provider_known_hosts not found."
    body = match.group(0)
    assert body.index("provider_host_key_material") < body.index("LEGACY_KNOWN_HOSTS"), \
        "The file is consulted before the stored keys; stored keys must win."


def test_empty_known_hosts_rejects_instead_of_accepting_anything():
    """The dangerous part of this API is that "nothing to trust" and "trust anything" look alike.

    asyncssh reads `known_hosts=None` AND `known_hosts=()` as "skip host key checking" - both
    connect to whatever answers. Only a seven-element tuple of empty lists rejects. Verified
    against a real node: `()` connected, `([], [], [], [], [], [], [])` raised
    HostKeyNotVerifiable. So the no-keys path must build the latter, never a bare empty value.
    """
    import server

    empty = server.known_hosts_of()
    assert isinstance(empty, tuple) and len(empty) == 7, \
        f"known_hosts_of() returned {empty!r}; asyncssh treats anything else as no checking."
    assert all(isinstance(part, list) and not part for part in empty), \
        "Every slot must be an empty list for asyncssh to reject rather than skip verification."
    assert empty, "An empty tuple is falsy and asyncssh skips verification for it."

    one = server.known_hosts_of("key")
    assert one[0] == ["key"] and len(one) == 7


def test_no_keys_path_does_not_hand_back_a_bare_empty_value():
    body = re.search(r"def provider_known_hosts.*?\n(?=\n\S|\nclass |\n@)", SERVER, re.S).group(0)
    for unsafe in ("return ()", "return None", "return []", 'return b""'):
        assert unsafe not in body, (
            f"provider_known_hosts has `{unsafe}`, which tells asyncssh to accept any host key. "
            "Return known_hosts_of() instead."
        )
