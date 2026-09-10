"""Password-based sudo execution shared by every SSH collector and diagnostic."""
import shlex
from types import SimpleNamespace

# sudo escalation for non-root SSH accounts (see run_as_root)
SUDO_PASSWORD_COMMAND = "sudo -S -p '' -k -H bash -c"
SUDO_PASSWORD_CHECK_COMMAND = "sudo -S -p '' -k -H true"
ROOT_MARKER = "__OKESTRO_ROOT_SHELL__"
# Linux caps one execve argument at MAX_ARG_STRLEN (128 KiB) and the sudo path passes the whole
# script as a single `bash -c` argument. Refuse earlier and name the cause: the kernel's
# "Argument list too long" says nothing an operator can act on. The root path (script on stdin)
# has no such limit, but shares the ceiling so a provider does not behave differently by account
# type. Built-in scripts are ~11 KB; the rest is provider input (log exclusion patterns).
MAX_SCRIPT_BYTES = 64 * 1024


class PrivilegeError(RuntimeError):
    """The login account could not obtain root on the target node."""


def sudo_failure_reason(stderr: str, exit_status: int | None) -> str:
    lines = [line.strip() for line in (stderr or "").splitlines() if line.strip()]
    message = lines[-1] if lines else f"exit {exit_status}"
    if "incorrect password" in message or "Sorry, try again" in message:
        return "sudo 비밀번호가 일치하지 않습니다"
    if "not in the sudoers" in message or "not allowed" in message:
        return f"sudo 권한이 없습니다 ({message})"
    if "tty" in message:
        return f"sudoers의 requiretty 설정으로 비대화형 sudo가 차단되었습니다 ({message})"
    if "password is required" in message:
        return "sudo 비밀번호가 필요합니다"
    return f"sudo 실행 실패 ({message})"


async def run_as_root(connection, provider: dict, script: str, timeout: int):
    """Run a check script as root on an established SSH connection.

    Non-root accounts always use a stored sudo password, supplied only on stdin.
    The script is a separately quoted bash argument, so even if sudo policy changes
    and no password is consumed, secret input can never be interpreted as shell code.
    Failed escalation never falls back to an unprivileged check.
    """
    script_bytes = len(script.encode("utf-8"))
    if script_bytes > MAX_SCRIPT_BYTES:
        raise PrivilegeError(f"점검 스크립트가 너무 깁니다({script_bytes // 1024}KB, 상한 {MAX_SCRIPT_BYTES // 1024}KB). "
                             "로그 제외 패턴이나 사용자 정의 점검 항목을 줄이세요.")
    if provider["username"] == "root":
        return await connection.run("bash -s", input=script, check=False, timeout=timeout)
    sudo_password = provider["credentials"].get("sudo_password")
    if not sudo_password or any(char in sudo_password for char in "\r\n\x00"):
        raise PrivilegeError(f"{provider['username']} 계정: 공급자 화면에서 sudo 비밀번호를 등록하세요")
    payload = f"[ \"$(id -u)\" = 0 ] || exit 1\nprintf '%s\\n' {ROOT_MARKER}\n" + script
    # Checks do not read authentication input, including when sudo does not consume it.
    command = f"{SUDO_PASSWORD_COMMAND} {shlex.quote('exec </dev/null; ' + payload)}"
    result = await connection.run(command, input=f"{sudo_password}\n", check=False, timeout=timeout)
    if not result.stdout.startswith(ROOT_MARKER + "\n"):
        raise PrivilegeError(f"{provider['username']} 계정: {sudo_failure_reason(result.stderr, result.exit_status)}")
    return SimpleNamespace(stdout=result.stdout[len(ROOT_MARKER) + 1:], stderr=result.stderr, exit_status=result.exit_status)


