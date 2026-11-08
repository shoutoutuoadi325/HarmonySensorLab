#!/usr/bin/env python3
"""Targeted official HDC/uitest phone evidence capture; never fabricates sensor readings."""
from pathlib import Path
import json, subprocess, sys, re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/emulator-runtime/phone'
OUT.mkdir(parents=True,exist_ok=True)
HDC='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
TARGET='127.0.0.1:12001'
def run(*args):
 p=subprocess.run([HDC,'-p','-t',TARGET,*args],text=True,capture_output=True,timeout=30)
 with (OUT/'commands.log').open('a') as f:
  f.write('$ hdc -p -t '+TARGET+' '+ ' '.join(args)+'\n'+p.stdout+p.stderr+'\n')
 if p.returncode: raise RuntimeError(p.stdout+p.stderr)
 return p.stdout

def nodes(node):
 yield node
 for child in node.get('children',[]): yield from nodes(child)

def capture(name,screenshot=True):
 remote='/data/local/tmp/harmony-phone-layout.json'
 run('shell','uitest','dumpLayout','-p',remote,'-a')
 run('file','recv',remote,str(OUT/(name+'.json')))
 obj=json.loads((OUT/(name+'.json')).read_text())
 texts=[]
 for node in nodes(obj):
  a=node.get('attributes',{})
  if a.get('text') or a.get('clickable')=='true' or a.get('type') in ('Canvas','Toggle','Scroll'):
   texts.append(a)
 md='# Phone emulator runtime: '+name+'\n\nThis is an API 26 virtual device; no physical sensor verification is claimed.\n\n'
 md+='\n'.join(f"- {a.get('type')} {a.get('text')} [{a.get('bounds')}] clickable={a.get('clickable')} enabled={a.get('enabled')} checked={a.get('checked')} description={a.get('description')}" for a in texts)
 (OUT/(name+'.md')).write_text(md+'\n')
 if screenshot:
  remote_png='/data/local/tmp/harmony-phone-screen.png'
  run('shell','uitest','screenCap','-p',remote_png)
  run('file','recv',remote_png,str(OUT/(name+'.png')))
 print(md)
 return texts

if __name__=='__main__':
 if sys.argv[1]=='capture': capture(sys.argv[2],True)
 elif sys.argv[1]=='click': run('shell','uitest','uiInput','click',sys.argv[2],sys.argv[3]); capture(sys.argv[4],True)
 elif sys.argv[1]=='swipe': run('shell','uitest','uiInput','swipe',*sys.argv[2:6]); capture(sys.argv[6],True)
 elif sys.argv[1]=='key': run('shell','uitest','uiInput','keyEvent',sys.argv[2]); capture(sys.argv[3],True)
