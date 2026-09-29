"""Create the requested private repository using the existing Git credential manager.

Credentials stay in memory and are never printed or saved. Run after reviewing the
local commit. This script refuses to reuse a nonempty or public repository.
"""
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request

OWNER='elliotthewizerd'
NAME='riscv-pipeline-tangnano9k'

def main():
    os.environ["GIT_CONFIG_COUNT"]="1"
    os.environ["GIT_CONFIG_KEY_0"]="safe.directory"
    os.environ["GIT_CONFIG_VALUE_0"]=Path(__file__).resolve().parents[1].as_posix()
    credential=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',
                              text=True,capture_output=True,check=True)
    fields=dict(line.split('=',1) for line in credential.stdout.splitlines() if '=' in line)
    token=fields.get('password')
    if not token: raise SystemExit('No GitHub credential available. Sign in through Git Credential Manager.')
    def api(method,path,data=None):
        req=urllib.request.Request('https://api.github.com'+path,
            data=None if data is None else json.dumps(data).encode(),method=method,
            headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json',
                     'X-GitHub-Api-Version':'2022-11-28','User-Agent':'riscv-project-publish'})
        try:
            with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
        except urllib.error.HTTPError as e:
            # Report API diagnostics only, never request headers or credentials.
            message=json.loads(e.read().decode()).get('message','')
            raise RuntimeError(f'GitHub HTTP {e.code}: {message}') from None
    profile=api('GET','/user')
    if profile['login'].lower()!=OWNER: raise SystemExit('Signed-in GitHub account differs from requested owner.')
    try:
        repo=api('GET',f'/repos/{OWNER}/{NAME}')
    except RuntimeError as e:
        if 'HTTP 404:' not in str(e): raise
        repo=api('POST','/user/repos',{'name':NAME,'private':True,'auto_init':False,
                 'description':'RV32 5-stage pipeline with forwarding, load-use interlock, branch flush, Tang Nano 9K build and original datapath drawings.'})
    if not repo['private']: raise SystemExit('Refusing to push: repository is not private.')
    if repo['size']!=0: raise SystemExit('Repository is not empty; inspect it before publishing.')
    remotes=subprocess.check_output(['git','remote'],text=True).split()
    if 'origin' in remotes:
        url=subprocess.check_output(['git','remote','get-url','origin'],text=True).strip()
        if url!=repo['clone_url']:raise SystemExit('Existing origin differs; inspect it first.')
    else:subprocess.run(['git','remote','add','origin',repo['clone_url']],check=True)
    subprocess.run(['git','push','-u','origin','main'],check=True)
    verified=api('GET',f'/repos/{OWNER}/{NAME}')
    print(f'Published {verified["html_url"]}; private={verified["private"]}')

if __name__=='__main__':main()
