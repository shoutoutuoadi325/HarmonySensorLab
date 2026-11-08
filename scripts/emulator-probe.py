#!/usr/bin/env python3
"""Read and operate an explicitly named test emulator using the official SDK uitest CLI."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
parser = argparse.ArgumentParser()
parser.add_argument('target')
parser.add_argument('folder')
parser.add_argument('name')
parser.add_argument('--click')
parser.add_argument('--expect')
parser.add_argument('--type')
parser.add_argument('--swipe', nargs=4, type=int)
parser.add_argument('--key')
args = parser.parse_args()
folder = ROOT / 'reports/emulator-runtime' / args.folder
folder.mkdir(parents=True, exist_ok=True)

def run(*command):
    result = subprocess.run([HDC, '-p', '-t', args.target, *command], capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

def nodes(node):
    yield node.get('attributes', {})
    for child in node.get('children', []):
        yield from nodes(child)

def layout():
    run('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/sensor-probe.json')
    path = folder / (args.name + '.json')
    run('file', 'recv', '/data/local/tmp/sensor-probe.json', str(path))
    return list(nodes(json.loads(path.read_text())))

current = layout()
if args.click:
    matches = [n for n in current if n.get('text') == args.click and n.get('enabled') == 'true'
               and (not args.type or n.get('type') == args.type)]
    if not matches:
        raise SystemExit('Visible enabled text not found: ' + args.click)
    # dumpLayout omits off-screen nodes: use the current visible bounds only.
    bounds = list(map(int, re.findall(r'-?\d+', matches[0]['bounds'])))
    x, y = (bounds[0] + bounds[2]) // 2, (bounds[1] + bounds[3]) // 2
    run('shell', 'uitest', 'uiInput', 'click', str(x), str(y))
elif args.swipe:
    run('shell', 'uitest', 'uiInput', 'swipe', *map(str, args.swipe), '1500')
elif args.key:
    run('shell', 'uitest', 'uiInput', 'keyEvent', args.key)
if args.click or args.swipe or args.key:
    time.sleep(0.6)
    current = layout()
if args.expect:
    for attempt in range(4):
        if any(args.expect in n.get('text', '') for n in current):
            break
        time.sleep(0.8)
        current = layout()
    else:
        raise SystemExit('Expected text missing: ' + args.expect)
run('shell', 'uitest', 'screenCap', '-p', '/data/local/tmp/sensor-probe.png')
run('file', 'recv', '/data/local/tmp/sensor-probe.png', str(folder / (args.name + '.png')))
print(json.dumps([{'text': n['text'], 'bounds': n.get('bounds')} for n in current if n.get('text')], ensure_ascii=False, indent=2))
