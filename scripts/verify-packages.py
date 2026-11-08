#!/usr/bin/env python3
import hashlib
import argparse
import json
import io
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--unsigned-only', action='store_true')
args = parser.parse_args()
expected = {'default': (['phone', 'tablet'], 50000012), 'pc': (['2in1'], 50001013),
            'wearable': (['wearable'], 50100018), 'tv': (['tv'], 50101019)}
permissions = {'ohos.permission.ACCELEROMETER', 'ohos.permission.GYROSCOPE', 'ohos.permission.ACTIVITY_MOTION'}
results = []
java = '/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/java'
sign_tool = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'

def signature_check(path, signed):
    with tempfile.TemporaryDirectory(prefix='sensor-package-verify-') as temp:
        result = subprocess.run([java, '-jar', sign_tool, 'verify-app', '-inFile', str(path),
                                 '-outCertChain', temp + '/chain.cer', '-outProfile', temp + '/profile.p7b'],
                                capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        if signed:
            assert result.returncode == 0 and 'verify-app success' in output
            assert 'profile type is: debug' in output
            assert 'verify codesign success' in output and 'verify permission sign success' in output
            assert 'Huawei CBG Root CA G2' in output
        else:
            assert result.returncode != 0 and 'No Hap Signing Block' in output
    return 'official debug signature verified' if signed else 'absence of signing block verified'

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
        signature = signature_check(package, False)
        results.append({'file': str(package.relative_to(root)), 'bytes': package.stat().st_size,
                        'sha256': hashlib.sha256(package.read_bytes()).hexdigest(), 'mode': mode,
                        'devices': devices, 'minimumApi': minimum, 'signed': False, 'signatureCheck': signature, 'checks': 'passed'})
    app = root / 'dist/packages' / f'sensor-{product}-release-unsigned.app'
    with ZipFile(app) as archive:
        names = archive.namelist()
        assert 'pack.info' in names and any(n.endswith('.hap') for n in names)
        embedded = archive.read(next(n for n in names if n.endswith('.hap')))
        with ZipFile(io.BytesIO(embedded)) as inner, ZipFile(root / 'dist/packages' / f'sensor-{product}-release-unsigned.hap') as outer:
            assert set(inner.namelist()) == set(outer.namelist())
            # APP packaging rewrites pack.info; executable code/resources/manifest must match Release HAP.
            assert all(inner.read(name) == outer.read(name) for name in outer.namelist() if name != 'pack.info')
        with tempfile.TemporaryDirectory(prefix='sensor-app-hap-') as temp:
            embedded_path = Path(temp) / 'embedded.hap'
            embedded_path.write_bytes(embedded)
            signature_check(embedded_path, False)
    results.append({'file': str(app.relative_to(root)), 'bytes': app.stat().st_size,
                    'sha256': hashlib.sha256(app.read_bytes()).hexdigest(), 'signed': False, 'checks': 'container and embedded Release HAP passed'})
    signed = root / 'dist/packages' / f'sensor-{product}-debug-signed.hap'
    if signed.exists() and not args.unsigned_only:
        with ZipFile(signed) as hap:
            manifest = json.loads(hap.read('module.json'))
            assert manifest['app']['debug'] is True
            assert set(manifest['module']['deviceTypes']) == set(devices)
            assert manifest['app']['minAPIVersion'] == minimum
            assert manifest['app']['targetAPIVersion'] == 260000026
            assert {p['name'] for p in manifest['module']['requestPermissions']} == permissions
            with ZipFile(root / 'dist/packages' / f'sensor-{product}-debug-unsigned.hap') as unsigned:
                # Official code signing adds page signature metadata outside the unsigned payload.
                assert set(hap.namelist()) == set(unsigned.namelist()) | {'.pages.info'}
                assert hap.read('.pages.info')
                assert all(hap.read(name) == unsigned.read(name) for name in unsigned.namelist())
        signature = signature_check(signed, True)
        results.append({'file': str(signed.relative_to(root)), 'bytes': signed.stat().st_size,
                        'sha256': hashlib.sha256(signed.read_bytes()).hexdigest(), 'signed': True,
                        'profileType': 'debug', 'signatureCheck': signature, 'checks': 'passed'})
print(json.dumps({'packages': results, 'note': 'Debug-signed HAPs are for authorized debugging. Release HAP/APP remain unsigned; emulator results do not establish physical hardware support or store approval.'}, ensure_ascii=False, indent=2))
