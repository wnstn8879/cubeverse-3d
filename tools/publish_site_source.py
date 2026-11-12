#!/usr/bin/env python3
"""Publish this owner-private Site from original game artifacts; credentials only via hidden stdin."""
import sys,json,os,base64,subprocess,termios,tarfile
from pathlib import Path
p=Path(sys.argv[1] if len(sys.argv)>1 else '/workspace/sites/cubeverse-play').resolve()
a=termios.tcgetattr(sys.stdin)
b=a.copy(); b[3] &= ~termios.ECHO
termios.tcsetattr(sys.stdin,termios.TCSANOW,b)
print('Ready for Site credential JSON on stdin (input is hidden).',flush=True)
try: obj=json.loads(sys.stdin.readline())
finally: termios.tcsetattr(sys.stdin,termios.TCSANOW,a)
c=obj['credential']; env=os.environ.copy()
expected_remote='https://git.chatgpt-team.site/17a5b53c-621f-46d7-8455-235f98db1867/appgprj_6af5d70449908191b003fe9ace1bc88e.git'
assert c['remote_url']==expected_remote and c['branch']=='main'
assert json.loads((p/'.openai/hosting.json').read_text())['project_id']=='appgprj_6af5d70449908191b003fe9ace1bc88e'
assert all(q.relative_to(p).parts[0] in ('dist','.openai','.git') for q in p.rglob('*') if q.is_file())
if c.get('auth_mode')!='work_proxy':
    env.update({'GIT_CONFIG_COUNT':'1','GIT_CONFIG_KEY_0':'http.extraHeader','GIT_CONFIG_VALUE_0':'Authorization: Bearer '+c['token']})
def run(args,net=False):
    r=subprocess.run(args,cwd=p,env=env if net else None,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if r.returncode:
        print('SOURCE_STEP_FAILED',args[0:2],r.returncode, r.stdout.replace(c.get('token','__NO_TOKEN__'),'[REDACTED]')[-2500:],flush=True)
        sys.exit(r.returncode)
    return r.stdout.strip()
if not (p/'.git').exists(): run(['git','init','-b',c['branch']])
run(['git','config','user.name','CubeVerse Build'])
run(['git','config','user.email','cubeverse-build@users.noreply.github.com'])
run(['git','add','.'])
if run(['git','status','--porcelain']): run(['git','commit','-m','Publish verified CubeVerse Godot web development build'])
remotes=run(['git','remote']).splitlines()
run(['git','remote','set-url' if 'origin' in remotes else 'add','origin',expected_remote])
# A new static export can exceed this provider's 64 MiB receive-pack limit.
# Preserve the original local commit, then send web and APK objects separately.
backup=run(['git','branch','--list','backup-before-size-split'])
if not backup and int(run(['git','rev-list','--count','HEAD'])) <= 2:
    run(['git','branch','backup-before-size-split'])
    run(['git','checkout','--orphan','split-web-upload'])
    run(['git','rm','-r','--cached','.'])
    web_files=[str(q.relative_to(p)) for q in (p/'dist').iterdir() if q.is_file() and not q.name.startswith('apk.part')]
    run(['git','add','.openai',*web_files])
    run(['git','commit','-m','Add verified Godot web export'])
    run(['git','branch','-M','main'])
    run(['git','push','-u','origin','main'],True)
    apk_files=[str(q.relative_to(p)) for q in (p/'dist').glob('apk.part*.bin')]
    run(['git','add',*apk_files])
    run(['git','commit','-m','Add verified debug APK download'])
run(['git','push','-u','origin',c['branch']],True)
sha=run(['git','rev-parse','HEAD'])
archive='/tmp/cubeverse-site-deploy.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
    tar.add(p/'.openai/hosting.json',arcname='.openai/hosting.json')
    tar.add(p/'dist',arcname='dist')
print(json.dumps({'project_id':'appgprj_6af5d70449908191b003fe9ace1bc88e','commit_sha':sha,'archive':archive}),flush=True)
