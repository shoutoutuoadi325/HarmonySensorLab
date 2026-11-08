#!/usr/bin/env python3
"""Use the IDE's private HarmonyOS debug material, then restore the portable profile."""
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
profile_file = root / 'build-profile.json5'
private = root / '.signing/deveco-signing.json'
if not private.is_file():
    raise SystemExit('Generate official debug signing in DevEco Studio first; see docs/signing-and-installation.md.')
material = json.loads(private.read_text())
original = profile_file.read_text()
profile = json.loads(original)
profile['app']['signingConfigs'] = material
for product in profile['app']['products']:
    product['signingConfig'] = material[0]['name']
lock = root / '.signing/build.lock'
fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
try:
    profile_file.write_text(json.dumps(profile, ensure_ascii=False, indent=2))
    for product in ['default', 'pc', 'wearable', 'tv']:
        log = root / 'reports' / ('build-debug-' + product + '-signed.log')
        result = subprocess.run([str(root / 'scripts/build.sh'), product, 'debug'], cwd=root,
                                capture_output=True, text=True)
        output = result.stdout + result.stderr
        for item in material:
            for value in item.get('material', {}).values():
                if isinstance(value, str) and len(value) > 8:
                    output = output.replace(value, '[private signing value]')
        log.write_text(output)
        if result.returncode:
            raise SystemExit('Debug signed build failed for ' + product + '; see sanitized build log.')
        source = root / ('entry/build/' + product + '/outputs/' + product + '/entry-' + product + '-signed.hap')
        shutil.copy2(source, root / ('dist/packages/sensor-' + product + '-debug-signed.hap'))
        print('Built official debug-signed HAP: ' + product)
finally:
    profile_file.write_text(original)
    os.close(fd)
    lock.unlink()
