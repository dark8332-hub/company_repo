"""Release failures exercised through real shell scripts and isolated, stateful runtime stubs."""
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

import pytest

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = ROOT / 'deploy'
spec = importlib.util.spec_from_file_location('restore_archive', DEPLOY / 'restore_archive.py')
restore_archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restore_archive)

RUNTIME = r'''
import json, os, pathlib, subprocess, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as out: out.write(json.dumps(args)+'\n')
if args[:1] == ['--namespace']: args = args[2:]
path = pathlib.Path(os.environ['STATE'])
state = json.loads(path.read_text())
cmd = args[0]
name = 'openstack-ops-platform'
def save(): path.write_text(json.dumps(state))
if cmd == 'info': pass
elif cmd == 'inspect':
    if os.environ.get('INSPECT_FAIL'): sys.exit(1)
    fmt = args[args.index('--format')+1]
    print(state.get('image', '') if 'Config.Image' in fmt else state.get('label', ''))
elif cmd == 'ps':
    if os.environ.get('PS_FAIL'): sys.exit(1)
    fmt = args[args.index('--format')+1]
    if 'Ports' in fmt:
        if os.environ.get('BUSY'): print('0.0.0.0:65432->8090/tcp')
    elif state['exists'] and ('-a' in args or state['running']): print(name)
elif cmd == 'stop': state['running'] = False; save()
elif cmd == 'start': state['running'] = True; save()
elif cmd == 'rm': state['exists'] = False; state['running'] = False; save()
elif cmd == 'run':
    if '--entrypoint' in args:
        mounts = [args[i+1].split(':') for i,a in enumerate(args) if a == '--volume']
        host = {m[1]:m[0] for m in mounts}
        sys.exit(subprocess.call([sys.executable,host['/restore_archive.py'],host['/backup.tar.gz'],host['/restore']]))
    state.update(exists=True,running=True,image=args[-1],label='openstack-ops-platform'); save()
    if os.environ.get('RUN_FAIL'): sys.exit(1)
elif cmd == 'exec':
    if not state['running']: sys.exit(1)
elif cmd == 'rmi': pass
'''


@pytest.fixture
def release_bundle(tmp_path):
    for name in ('lib.sh', 'install.sh', 'opsctl.sh', 'restore_archive.py'):
        shutil.copy(DEPLOY / name, tmp_path / name)
    (tmp_path / 'config.env').write_text('IMAGE_TAG=1.1.5\nHOST_PORT=65432\n')
    data = tmp_path / 'data'; data.mkdir()
    (data / 'providers.db').write_bytes(b'original-db')
    (data / '.master_key').write_bytes(b'original-key')
    bindir = tmp_path / 'bin'; bindir.mkdir()
    runtime = bindir / 'docker'
    runtime.write_text(f'#!{sys.executable}\n' + RUNTIME); runtime.chmod(0o755)
    state = {'exists':True,'running':True,'image':'okestro/openstack-ops-platform:1.1.4','label':''}
    (tmp_path / 'state').write_text(json.dumps(state))
    return tmp_path


def environment(bundle, **extra):
    return {**os.environ, 'PATH':f'{bundle}/bin:/usr/bin:/bin', 'STATE':str(bundle/'state'),
            'CALLS':str(bundle/'calls'), **extra}


def run(bundle, command, *args, **extra):
    return subprocess.run(['/bin/sh', str(bundle/'opsctl.sh'), command, *map(str,args)],
                          env=environment(bundle, **extra), text=True, capture_output=True, timeout=15)


def state(bundle): return json.loads((bundle/'state').read_text())
def calls(bundle): return [json.loads(line) for line in (bundle/'calls').read_text().splitlines()]


def archive_at(path, entries):
    with tarfile.open(path, 'w:gz') as out:
        for name, contents, kind in entries:
            member = tarfile.TarInfo(name); member.type = kind
            if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE): member.linkname = contents
            else: member.size = len(contents)
            out.addfile(member, io.BytesIO(contents) if isinstance(contents, bytes) else None)
    return path


@pytest.mark.parametrize('command', ['start','stop','restart','backup','restore','remove','logs','shell'])
@pytest.mark.parametrize('identity', ['foreign','unknown','misleading','foreign-label','inspect-error'])
def test_foreign_or_unknown_container_never_mutated(release_bundle, command, identity):
    bundle = release_bundle
    current = state(bundle)
    current['image'] = {'foreign':'other/app:1', 'unknown':'',
                        'misleading':'other/okestro/openstack-ops-platform:1',
                        'foreign-label':'okestro/openstack-ops-platform:1',
                        'inspect-error':'okestro/openstack-ops-platform:1'}[identity]
    if identity == 'foreign-label': current['label'] = 'another-app'
    (bundle/'state').write_text(json.dumps(current))
    before = (bundle/'data/providers.db').read_bytes()
    result = run(bundle, command, **({'INSPECT_FAIL':'1'} if identity == 'inspect-error' else {}))
    assert result.returncode != 0
    assert not any(c[0] in {'rm','run','stop','start','rmi','exec'} for c in calls(bundle))
    assert state(bundle) == current and (bundle/'data/providers.db').read_bytes() == before


@pytest.mark.parametrize('command', ['restart','restore'])
def test_port_conflict_preserves_old_container_and_data(release_bundle, command):
    bundle = release_bundle
    archive = archive_at(bundle/'backup.tar.gz', [('data/providers.db',b'restored',tarfile.REGTYPE)])
    result = run(bundle, command, *([archive] if command == 'restore' else []), BUSY='1')
    assert result.returncode != 0
    assert state(bundle)['running'] and state(bundle)['exists']
    assert (bundle/'data/providers.db').read_bytes() == b'original-db'
    assert not any(c[0] in {'rm','run'} for c in calls(bundle))


def test_start_refuses_busy_port_without_creating_container(release_bundle):
    bundle = release_bundle
    current = state(bundle); current.update(exists=False,running=False)
    (bundle/'state').write_text(json.dumps(current))
    assert run(bundle,'start',BUSY='1').returncode != 0
    assert not any(c[0] == 'run' for c in calls(bundle))


@pytest.mark.parametrize('initial_running', [True,False])
@pytest.mark.parametrize('failure', [False,True])
def test_backup_restores_original_state_and_publishes_only_complete_file(release_bundle, initial_running, failure):
    bundle = release_bundle
    current = state(bundle); current['running'] = initial_running
    (bundle/'state').write_text(json.dumps(current))
    if failure:
        fake = bundle/'bin/tar'; fake.write_text('#!/bin/sh\nexit 1\n'); fake.chmod(0o755)
    target = bundle/'result.tar.gz'
    result = run(bundle,'backup',target)
    assert (result.returncode == 0) == (not failure), result.stdout+result.stderr
    assert state(bundle)['running'] == initial_running
    assert target.exists() == (not failure)
    assert not list(bundle.glob('*.partial.*'))
    if target.exists():
        assert target.stat().st_mode & 0o777 == 0o600
        with tarfile.open(target) as source: assert source.extractfile('data/.master_key').read() == b'original-key'


def test_absolute_nerdctl_always_uses_namespace(release_bundle):
    bundle = release_bundle
    runtime = bundle/'bin/nerdctl'; shutil.copy(bundle/'bin/docker',runtime)
    result = run(bundle,'status',OPS_RUNTIME=str(runtime))
    assert result.returncode == 0, result.stdout+result.stderr
    assert calls(bundle) and all(c[:2] == ['--namespace','openstack-ops'] for c in calls(bundle))


@pytest.mark.parametrize('bad', [
    ('config.env',b'IMAGE_TAG=foreign',tarfile.REGTYPE),
    ('/tmp/escape',b'bad',tarfile.REGTYPE),
    ('data/../config.env',b'bad',tarfile.REGTYPE),
    ('data/link','../../config.env',tarfile.SYMTYPE),
    ('data/link','data/providers.db',tarfile.LNKTYPE),
    ('data/pipe',b'',tarfile.FIFOTYPE),
    ('data/providers.db',b'duplicate',tarfile.REGTYPE),
    ('data/providers.db/child',b'conflict',tarfile.REGTYPE),
])
def test_invalid_restore_never_stops_service_or_changes_files(release_bundle, bad):
    bundle = release_bundle
    archive = archive_at(bundle/'bad.tar.gz',[('data/providers.db',b'restored',tarfile.REGTYPE),bad])
    config = (bundle/'config.env').read_bytes()
    result = run(bundle,'restore',archive)
    assert result.returncode != 0
    assert (bundle/'config.env').read_bytes() == config
    assert (bundle/'data/providers.db').read_bytes() == b'original-db'
    assert state(bundle)['running']
    assert not any(c[0] in {'stop','rm','run'} for c in calls(bundle))
    assert not list(bundle.glob('.restore.*'))


def test_restore_valid_backup_preserves_old_data(release_bundle):
    bundle = release_bundle
    archive = archive_at(bundle/'valid.tar.gz',[('data/providers.db',b'restored',tarfile.REGTYPE),
                                               ('data/.master_key',b'new-key',tarfile.REGTYPE)])
    result = run(bundle,'restore',archive)
    assert result.returncode == 0, result.stdout+result.stderr
    assert (bundle/'data/providers.db').read_bytes() == b'restored'
    old = list(bundle.glob('data.before-restore.*'))
    assert len(old) == 1 and (old[0]/'.master_key').read_bytes() == b'original-key'
    assert state(bundle)['running']


def test_runtime_run_failure_stops_new_container(release_bundle):
    result = run(release_bundle,'restart',RUN_FAIL='1')
    assert result.returncode != 0
    assert not state(release_bundle)['running']


def test_release_version_and_required_files_ship():
    import app_metadata
    assert app_metadata.APP_VERSION == (ROOT/'VERSION').read_text().strip()
    assert 'COPY VERSION' in (ROOT/'Dockerfile').read_text()
    build = (ROOT/'build-offline-bundle.sh').read_text()
    assert 'deploy/restore_archive.py' in build
    assert '--platform linux/amd64' in build


def test_restore_uses_bundled_python_when_host_has_none(release_bundle):
    bundle = release_bundle
    toolbox = bundle/'toolbox'; toolbox.mkdir()
    for tool in ('dirname','basename','pwd','mktemp','mkdir','rm','rmdir','mv','grep','awk','tr','head','cat','ss','hostname'):
        found = shutil.which(tool)
        if found: (toolbox/tool).symlink_to(found)
    archive = archive_at(bundle/'valid.tar.gz',[('data/providers.db',b'restored',tarfile.REGTYPE)])
    result = run(bundle,'restore',archive,PATH=f'{bundle}/bin:{toolbox}')
    assert result.returncode == 0, result.stdout+result.stderr
    assert (bundle/'data/providers.db').read_bytes() == b'restored'
    helper = [c for c in calls(bundle) if '--entrypoint' in c]
    assert len(helper) == 1 and helper[0][helper[0].index('--network')+1] == 'none'


def test_backup_signal_restores_service_and_retains_existing_backup(release_bundle):
    bundle = release_bundle
    fake = bundle/'bin/tar'
    fake.write_text('#!/bin/sh\nkill -TERM "$PPID"\nexit 1\n'); fake.chmod(0o755)
    target = bundle/'existing.tar.gz'; target.write_bytes(b'previous good backup')
    result = run(bundle,'backup',target)
    assert result.returncode != 0
    assert state(bundle)['running']
    assert target.read_bytes() == b'previous good backup'
    assert not list(bundle.glob('*.partial.*'))


def test_failed_container_listing_never_authorizes_removal(release_bundle):
    result = run(release_bundle, 'remove', '--all', PS_FAIL='1')
    assert result.returncode != 0
    assert (release_bundle/'data/providers.db').read_bytes() == b'original-db'
    assert not any(c[0] in {'rm','run','stop','rmi'} for c in calls(release_bundle))
