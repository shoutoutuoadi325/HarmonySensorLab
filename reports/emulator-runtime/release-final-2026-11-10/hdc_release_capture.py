#!/usr/bin/env python3
"""Capture actual Release app UI on explicitly identified local test emulators.

This workflow never starts a desktop app or substitutes a Debug package.
It preserves original PNGs and records the exact successfully installed HAP.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
BUNDLE = 'com.personal.harmonysensorlab'
PRODUCTS = {'phone': 'default', 'tablet': 'default', 'pc': 'pc', 'watch': 'wearable'}
EXPECTED = {
    'default': '5b51c3e763d9dabb52f7defa5564061e6a5916b6f18c764d07b523319f07a2ee',
    'pc': '27711ea7c708579278f5f83d815ec7b8ab101e9e4b675327074d271aa91ff562',
    'wearable': '522b75ca70d6946c7b8ea39e244e96a5d1a066320d92dc3fd62e84d68448bf4f',
}

def now():
    return datetime.now(timezone.utc).isoformat()

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def nodes(node):
    yield node.get('attributes', {})
    for child in node.get('children', []):
        yield from nodes(child)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', default='127.0.0.1:8710')
    parser.add_argument('--target')
    parser.add_argument('--device', choices=PRODUCTS)
    parser.add_argument('--name', default='current')
    parser.add_argument('--text')
    parser.add_argument('--swipe', nargs=4, type=int)
    parser.add_argument('action', choices=['discover', 'identity', 'install', 'launch', 'capture', 'click', 'swipe', 'home'])
    args = parser.parse_args()
    if not re.fullmatch(r'127\.0\.0\.1:\d+', args.server):
        parser.error('Only the explicitly managed local HDC server is allowed.')
    if args.action != 'discover':
        if not args.target or not args.device or not re.fullmatch(r'127\.0\.0\.1:\d+', args.target):
            parser.error('Specify an explicitly identified local emulator target and device.')
        if not re.fullmatch(r'[a-zA-Z0-9_-]+', args.name):
            parser.error('name must contain only letters, numbers, dash and underscore.')
    folder = OUT / (args.device or 'discovery')
    folder.mkdir(parents=True, exist_ok=True)
    def run(*command, targeted=True):
        cmd = [HDC, '-p', '-s', args.server]
        if targeted:
            cmd += ['-t', args.target]
        cmd += list(command)
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=30)
        item = {'atUtc': now(), 'command': cmd, 'exitCode': result.returncode,
                'stdout': result.stdout, 'stderr': result.stderr}
        with (folder / 'commands.jsonl').open('a') as file:
            file.write(json.dumps(item, ensure_ascii=False) + '\n')
        if result.returncode or 'Connect server failed' in result.stdout or 'Invalid parameters.' in result.stdout:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout
    if args.action == 'discover':
        output = run('list', 'targets', '-v', targeted=False)
        print(output)
        save(folder / 'current.json', {'atUtc': now(), 'server': args.server, 'output': output})
        return
    identity_file = folder / 'identity.json'
    if args.action == 'identity':
        identity = {'atUtc': now(), 'server': args.server, 'target': args.target, 'device': args.device,
                    'testEmulator': True, 'declaredByCaller': True, 'properties': {}}
        for key in ['const.product.devicetype', 'const.product.model', 'const.product.name',
                    'const.ohos.apiversion', 'const.product.software.version', 'const.product.hardware']:
            identity['properties'][key] = run('shell', 'param', 'get', key).strip()
        save(identity_file, identity)
        print(json.dumps(identity, ensure_ascii=False, indent=2))
        return
    if not identity_file.is_file():
        raise RuntimeError('Record current emulator identity before mutation or capture.')
    identity = json.loads(identity_file.read_text())
    if identity.get('target') != args.target or identity.get('server') != args.server:
        raise RuntimeError('Current target does not match the recorded identity.')
    package = ROOT / 'dist/packages' / f'sensor-{PRODUCTS[args.device]}-release-signed.hap'
    if digest(package) != EXPECTED[PRODUCTS[args.device]]:
        raise RuntimeError('Current Release HAP differs from the verified build; do not install or claim prior verification.')
    install_file = folder / 'install.json'
    if args.action == 'install':
        output = run('install', '-r', str(package))
        result = {'atUtc': now(), 'target': args.target, 'package': str(package.relative_to(ROOT)),
                  'packageSha256': digest(package), 'output': output,
                  'successful': 'success' in output.lower() and not any(x in output.lower() for x in ['failed', 'failure', 'error:'])}
        save(install_file, result)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if not result['successful']:
            raise RuntimeError('Release installation was not confirmed. No Debug fallback is performed.')
        return
    if not install_file.is_file():
        raise RuntimeError('No confirmed current Release installation for this emulator.')
    installed = json.loads(install_file.read_text())
    if not installed.get('successful') or installed.get('target') != args.target or installed.get('packageSha256') != digest(package):
        raise RuntimeError('Current confirmed Release installation is missing or mismatched.')
    if args.action == 'launch':
        print(run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', BUNDLE))
        return
    remote = '/data/local/tmp/harmonysensorlab-release-' + args.device
    def layout():
        run('shell', 'uitest', 'dumpLayout', '-p', remote + '.json', '-a')
        path = folder / (args.name + '.json')
        run('file', 'recv', remote + '.json', str(path))
        return list(nodes(json.loads(path.read_text())))
    current = layout()
    if args.action == 'click':
        if not args.text:
            parser.error('click requires --text from the most recent current layout.')
        matches = [n for n in current if n.get('text') == args.text and n.get('enabled') == 'true']
        if not matches:
            raise RuntimeError('Current enabled visible text is missing: ' + args.text)
        bounds = list(map(int, re.findall(r'-?\d+', matches[0]['bounds'])))
        run('shell', 'uitest', 'uiInput', 'click', str((bounds[0] + bounds[2]) // 2), str((bounds[1] + bounds[3]) // 2))
        current = layout()
    elif args.action == 'swipe':
        if not args.swipe:
            parser.error('swipe requires four coordinates from current layout bounds.')
        run('shell', 'uitest', 'uiInput', 'swipe', *map(str, args.swipe), '1500')
        current = layout()
    elif args.action == 'home':
        run('shell', 'uitest', 'uiInput', 'keyEvent', 'Home')
        current = layout()
    run('shell', 'uitest', 'screenCap', '-p', remote + '.png')
    screenshot = folder / (args.name + '.png')
    run('file', 'recv', remote + '.png', str(screenshot))
    texts = [{'text': n['text'], 'bounds': n.get('bounds'), 'type': n.get('type')} for n in current if n.get('text')]
    save(folder / (args.name + '-evidence.json'), {'atUtc': now(), 'identity': identity,
          'installedPackageSha256': digest(package), 'installedPackage': str(package.relative_to(ROOT)),
          'screenshot': str(screenshot.relative_to(ROOT)), 'screenshotSha256': digest(screenshot),
          'pixelTransformation': 'None; original official emulator screenshot',
          'provenance': 'Official HarmonyOS emulator; virtual sensor callbacks are not physical hardware evidence',
          'visibleText': texts})
    print(json.dumps(texts, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
