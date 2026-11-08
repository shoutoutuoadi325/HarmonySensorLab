#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
expected = {'default': (['phone', 'tablet'], 50000012), 'pc': (['2in1'], 50001013),
            'wearable': (['wearable'], 50100018), 'tv': (['tv'], 50101019)}
permissions = {'ohos.permission.ACCELEROMETER', 'ohos.permission.GYROSCOPE', 'ohos.permission.ACTIVITY_MOTION'}
results = []
for product, (devices, minimum) in expected.items():
    for mode in ('debug', 'release'):
        package = root / 'dist/packages' / f'sensor-{product}-{mode}-unsigned.hap'
        with ZipFile(package) as hap:
            manifest = json.loads(hap.read('module.json'))
            assert set(manifest['module']['deviceTypes']) == set(devices)
            assert manifest['app']['minAPIVersion'] == minimum
            assert manifest['app']['targetAPIVersion'] == 260000026
            assert manifest['app']['debug'] == (mode == 'debug')
            assert {p['name'] for p in manifest['module']['requestPermissions']} == permissions
            assert 'ets/modules.abc' in hap.namelist()
            assert 'resources.index' in hap.namelist()
        results.append({'file': str(package.relative_to(root)), 'bytes': package.stat().st_size,
                        'sha256': hashlib.sha256(package.read_bytes()).hexdigest(), 'mode': mode,
                        'devices': devices, 'minimumApi': minimum, 'signed': False, 'checks': 'passed'})
    app = root / 'dist/packages' / f'sensor-{product}-release-unsigned.app'
    with ZipFile(app) as archive:
        names = archive.namelist()
        assert 'pack.info' in names and any(n.endswith('.hap') for n in names)
    results.append({'file': str(app.relative_to(root)), 'bytes': app.stat().st_size,
                    'sha256': hashlib.sha256(app.read_bytes()).hexdigest(), 'signed': False, 'checks': 'container passed'})
print(json.dumps({'packages': results, 'note': 'Unsigned archives; package checks do not establish installation or device support.'}, ensure_ascii=False, indent=2))
