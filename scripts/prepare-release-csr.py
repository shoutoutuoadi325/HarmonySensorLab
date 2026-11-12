#!/usr/bin/env python3
"""Prepare a local P-256 signing key and public CSR for Huawei's release CA."""
import json
import os
import secrets
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / '.signing/release'
PRIVATE.mkdir(parents=True, exist_ok=True, mode=0o700)
PRIVATE.chmod(0o700)
MATERIAL = PRIVATE / 'material.json'
KEYSTORE = PRIVATE / 'harmonysensorlab-release.p12'
CSR = PRIVATE / 'harmonysensorlab-release.csr'
KEYTOOL = '/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/keytool'

if MATERIAL.exists():
    material = json.loads(MATERIAL.read_text())
else:
    if KEYSTORE.exists():
        raise SystemExit('Existing release key has no local material record; preserve it and resolve before proceeding.')
    material = {'keyAlias': 'harmonysensorlab-release',
                'storePassword': secrets.token_urlsafe(36),
                'keyAlgorithm': 'EC', 'curve': 'secp256r1',
                'signAlgorithm': 'SHA256withECDSA',
                'keyStore': str(KEYSTORE), 'csr': str(CSR),
                'status': 'CSR only; official release certificate and Profile still required'}
    fd = os.open(MATERIAL, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump(material, file, indent=2)
        file.write('\n')

environment = dict(os.environ)
environment['HARMONY_RELEASE_STORE_PASS'] = material['storePassword']

def run(*arguments):
    result = subprocess.run([KEYTOOL, *arguments], env=environment,
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        output = (result.stdout + result.stderr).replace(material['storePassword'], '[redacted]')
        raise SystemExit(output)

if not KEYSTORE.exists():
    run('-genkeypair', '-alias', material['keyAlias'], '-keyalg', 'EC',
        '-groupname', 'secp256r1', '-sigalg', 'SHA256withECDSA',
        '-dname', 'CN=Harmony Sensor Lab Release', '-validity', '3650',
        '-keystore', str(KEYSTORE), '-storetype', 'PKCS12',
        '-storepass:env', 'HARMONY_RELEASE_STORE_PASS',
        '-keypass:env', 'HARMONY_RELEASE_STORE_PASS')
    KEYSTORE.chmod(0o600)
if not CSR.exists():
    run('-certreq', '-alias', material['keyAlias'], '-sigalg', 'SHA256withECDSA',
        '-keystore', str(KEYSTORE), '-storetype', 'PKCS12',
        '-storepass:env', 'HARMONY_RELEASE_STORE_PASS', '-file', str(CSR))
    CSR.chmod(0o600)

print('Release key remains private locally. Public CSR ready: .signing/release/harmonysensorlab-release.csr')
print('An official Huawei release certificate and release Profile are required before production signing.')
