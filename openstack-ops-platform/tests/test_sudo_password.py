import asyncio
import shlex
from types import SimpleNamespace

import pytest
import provider_store
import server
import ssh_privileges


class Connection:
    def __init__(self, fail=False, consume=True):
        self.calls = []
        self.fail = fail
        self.consume = consume

    async def run(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if self.fail:
            return SimpleNamespace(stdout='', stderr='sudo: incorrect password', exit_status=1)
        args = shlex.split(command)
        assert args[:8] == ['sudo', '-S', '-p', '', '-k', '-H', 'bash', '-c']
        proc = await asyncio.create_subprocess_exec('bash', '-c', args[8], stdin=asyncio.subprocess.PIPE,
                                                  stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        stdout, stderr = await proc.communicate(b'' if self.consume else kwargs['input'].encode())
        return SimpleNamespace(stdout=stdout.decode(), stderr=stderr.decode(), exit_status=proc.returncode)


@pytest.mark.parametrize('mode', ['password', 'passwordless', 'authentication_required'])
@pytest.mark.parametrize('consume', [True, False])
def test_password_is_never_executed_or_exposed(mode, consume):
    secret = 'echo PASSWORD_MUST_NOT_EXECUTE; $(id)'
    conn = Connection(consume=consume)
    provider = {'username': 'operator', 'sudo_mode': mode, 'credentials': {'sudo_password': secret}}
    result = asyncio.run(server.run_as_root(conn, provider, "printf '%s\\n' \"quoted ' script\"; cat", 10))
    assert result.stdout == "quoted ' script\n"
    assert result.exit_status == 0
    assert len(conn.calls) == 1
    assert secret not in conn.calls[0][0]
    assert conn.calls[0][1]['input'] == secret + '\n'


@pytest.mark.parametrize('secret', [None, '', 'bad\npassword', 'bad\rpassword'])
def test_missing_password_blocks_legacy_provider(secret):
    conn = Connection()
    with pytest.raises(server.PrivilegeError, match='sudo 비밀번호를 등록'):
        asyncio.run(server.run_as_root(conn, {'username': 'operator', 'sudo_mode': 'passwordless',
                                           'credentials': {'sudo_password': secret}}, 'id', 10))
    assert not conn.calls


def test_wrong_password_does_not_fall_back():
    conn = Connection(fail=True)
    with pytest.raises(server.PrivilegeError, match='일치하지 않습니다'):
        asyncio.run(server.run_as_root(conn, {'username': 'operator', 'credentials': {'sudo_password': 'wrong'}}, 'id', 10))
    assert len(conn.calls) == 1


@pytest.mark.parametrize('valid', [True, False])
def test_registration_and_edit_require_password(auth_client, monkeypatch, valid):
    import provider_store
    key = server.asyncssh.generate_private_key('ssh-ed25519')
    fingerprint = key.get_fingerprint('sha256')
    calls = []

    async def scan(*args):
        return key, fingerprint

    class SSH:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            pass

        async def run(self, command, **kwargs):
            calls.append((command, kwargs))
            if command == server.SUDO_PASSWORD_CHECK_COMMAND:
                return SimpleNamespace(stdout='', stderr='' if valid else 'incorrect password', exit_status=0 if valid else 1)
            assert 'passwordless' not in command and 'sudo -n' not in command
            return SimpleNamespace(stdout='hostname=controller\nuser=operator\nsudo=authentication_required\n', stderr='', exit_status=0)

    monkeypatch.setattr(server, 'scan_ssh_host_key', scan)
    monkeypatch.setattr(server.asyncssh, 'connect', lambda *args, **kwargs: SSH())
    payload = dict(provider_name='Password Site', vip='192.0.2.10', username='operator', auth_method='password',
                   password='ssh-secret', sudo_password='sudo-secret', trusted_fingerprint=fingerprint)
    response = auth_client.post('/api/providers/connect', json=payload)
    assert response.status_code == (200 if valid else 400), response.text
    assert calls[-1][1]['input'] == 'sudo-secret\n'
    if valid:
        pid = response.json()['provider_id']
        stored = provider_store.get_provider(pid)
        assert stored['sudo_mode'] == 'password'
        assert stored['credentials']['sudo_password'] == 'sudo-secret'
        assert 'sudo-secret' not in response.text
        response = auth_client.put(f'/api/providers/{pid}', json=dict(name='Edited', vip='192.0.2.10', username='operator',
                                                                     sudo_password='replacement'))
        assert response.status_code == 200, response.text
        assert calls[-1][1]['input'] == 'replacement\n'
        assert provider_store.get_provider(pid)['credentials']['sudo_password'] == 'replacement'


@pytest.mark.parametrize('username', ['root', 'operator'])
def test_oversized_script_is_refused_before_execution(username):
    """A script beyond MAX_ARG_STRLEN would die as a kernel "Argument list too long" with no
    usable message. Both account types refuse it first, so a provider does not behave
    differently by account, and nothing reaches the node."""
    connection = Connection()
    provider = {'username': username, 'credentials': {'sudo_password': 'secret'}}
    script = 'echo x\n' * (ssh_privileges.MAX_SCRIPT_BYTES // 7 + 1)
    with pytest.raises(ssh_privileges.PrivilegeError) as error:
        asyncio.run(ssh_privileges.run_as_root(connection, provider, script, 20))
    assert '점검 스크립트가 너무 깁니다' in str(error.value)
    assert connection.calls == []


def test_script_at_the_ceiling_still_runs():
    connection = Connection()
    provider = {'username': 'operator', 'credentials': {'sudo_password': 'secret'}}
    padding = ssh_privileges.MAX_SCRIPT_BYTES - len('printf ok\n') - 1
    result = asyncio.run(ssh_privileges.run_as_root(connection, provider, 'printf ok\n' + '#' * padding, 20))
    assert result.stdout == 'ok'


def test_log_exclusion_patterns_are_capped_at_registration(auth_client, provider_id):
    """The node script carries every pattern, so the ceiling is reported here rather than
    surfacing mid-inspection as a failed check."""
    accepted = 0
    for index in range(200):
        pattern = f'{index:04d}' + 'x' * 290
        response = auth_client.post(f'/api/providers/{provider_id}/log-exclusions',
                                    json={'service': '', 'pattern': pattern, 'reason': 'noise'})
        if response.status_code == 400:
            assert '상한' in response.json()['detail']
            break
        assert response.status_code == 200, response.text
        accepted += 1
    else:
        pytest.fail('the exclusion budget was never enforced')
    assert accepted > 0
    stored = sum(len(rule['pattern'].encode()) for rule in provider_store.list_log_exclusions(provider_id))
    assert stored <= server.LOG_EXCLUSION_BUDGET_BYTES
