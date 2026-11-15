#!/usr/bin/env python3
"""Commit static artifacts in bounded pushes to this owner-private Site.

The Sites credential is accepted only over hidden terminal stdin. Tokens remain
in process memory; neither Git config files nor command arguments contain them.
"""
from pathlib import Path
import json
import os
import subprocess
import sys
import tarfile
import termios

PROJECT_ID = 'appgprj_6af5d70449908191b003fe9ace1bc88e'
REMOTE = 'https://git.chatgpt-team.site/17a5b53c-621f-46d7-8455-235f98db1867/appgprj_6af5d70449908191b003fe9ace1bc88e.git'
BATCH_LIMIT = 40 * 1024 * 1024  # Provider receive-pack limit is 64 MiB.
ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else '/workspace/sites/cubeverse-play').resolve()
terminal = termios.tcgetattr(sys.stdin)
hidden = terminal.copy()
hidden[3] &= ~termios.ECHO
termios.tcsetattr(sys.stdin, termios.TCSANOW, hidden)
print('Ready for Site credential JSON on stdin (input is hidden).', flush=True)
try:
    credential = json.loads(sys.stdin.readline())['credential']
finally:
    termios.tcsetattr(sys.stdin, termios.TCSANOW, terminal)
assert credential['remote_url'] == REMOTE and credential['branch'] == 'main'
assert json.loads((ROOT / '.openai/hosting.json').read_text())['project_id'] == PROJECT_ID
assert all(p.relative_to(ROOT).parts[0] in ('dist', '.openai', '.git') for p in ROOT.rglob('*') if p.is_file())
environment = os.environ.copy()
if credential.get('auth_mode') != 'work_proxy':
    environment.update(GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='http.extraHeader',
                       GIT_CONFIG_VALUE_0='Authorization: Bearer ' + credential['token'])


def run(arguments, network=False):
    result = subprocess.run(arguments, cwd=ROOT, env=environment if network else None,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode:
        safe = result.stdout.replace(credential.get('token', '__NO_TOKEN__'), '[REDACTED]')
        print('SOURCE_STEP_FAILED', arguments[:2], result.returncode, safe[-2500:], flush=True)
        raise SystemExit(result.returncode)
    return result.stdout.strip()


if not (ROOT / '.git').exists():
    run(['git', 'init', '-b', 'main'])
run(['git', 'config', 'user.name', 'CubeVerse Build'])
run(['git', 'config', 'user.email', 'cubeverse-build@users.noreply.github.com'])
remotes = run(['git', 'remote']).splitlines()
run(['git', 'remote', 'set-url' if 'origin' in remotes else 'add', 'origin', REMOTE])
head = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD'], cwd=ROOT,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if head.returncode == 0:
    # Flush a pending bounded commit before adding more objects after a retry.
    run(['git', 'push', '-u', 'origin', 'main'], True)


def commit_batch(paths, label):
    if not paths:
        return
    run(['git', 'add', '--', *paths])
    if run(['git', 'diff', '--cached', '--name-only']):
        run(['git', 'commit', '-m', label])
        run(['git', 'push', '-u', 'origin', 'main'], True)


# Deletions contain no new blobs. Never stage all modifications at once.
deleted = run(['git', 'ls-files', '--deleted', '-z']).split('\0')
commit_batch([p for p in deleted if p], 'Remove obsolete static artifacts')
files = sorted([p for base in (ROOT / '.openai', ROOT / 'dist') for p in base.rglob('*') if p.is_file()],
               key=lambda p: (p.name.startswith('apk.part'), str(p)))
batch = []
size = 0
for file in files:
    length = file.stat().st_size
    if length > BATCH_LIMIT:
        raise SystemExit('Static artifact exceeds bounded push size: ' + file.name)
    if batch and size + length > BATCH_LIMIT:
        commit_batch(batch, 'Update verified CubeVerse static artifacts')
        batch, size = [], 0
    batch.append(str(file.relative_to(ROOT)))
    size += length
commit_batch(batch, 'Update verified CubeVerse static artifacts')
assert not run(['git', 'status', '--porcelain']), 'Generated hosting checkout has unsaved files'
sha = run(['git', 'rev-parse', 'HEAD'])
archive = '/tmp/cubeverse-site-deploy.tar.gz'
with tarfile.open(archive, 'w:gz') as bundle:
    bundle.add(ROOT / '.openai/hosting.json', arcname='.openai/hosting.json')
    bundle.add(ROOT / 'dist', arcname='dist')
print(json.dumps({'project_id': PROJECT_ID, 'commit_sha': sha, 'archive': archive}), flush=True)
