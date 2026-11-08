#!/usr/bin/env python3
"""Export the auditable source and unsigned development-stage delivery."""
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
profile = json.loads((root / 'build-profile.json5').read_text())
if profile['app']['signingConfigs']:
    raise SystemExit('Signing configuration is present. Prepare a sanitized source profile before exporting credentials.')
archives = root / 'dist/archives'
archives.mkdir(parents=True, exist_ok=True)
source = archives / 'HarmonySensorLab-source-1.0.0.zip'
folders = ['AppScope', 'entry/src', 'docs', 'scripts', 'tests', 'reports', 'hvigor']
files = ['README.md', '.gitignore', 'build-profile.json5', 'hvigorfile.ts', 'oh-package.json5',
         'entry/build-profile.json5', 'entry/hvigorfile.ts', 'entry/oh-package.json5']
for folder in folders:
    files.extend(str(f.relative_to(root)) for f in sorted((root / folder).rglob('*')) if f.is_file())
for filename in files:
    if Path(filename).suffix.lower() in {'.p12', '.p7b', '.cer', '.keystore', '.pem', '.key'}:
        raise SystemExit('Credentials must not be included in source: ' + filename)
with ZipFile(source, 'w', ZIP_DEFLATED) as archive:
    for filename in sorted(files):
        archive.write(root / filename, 'HarmonySensorLab/' + filename)
with ZipFile(archives / 'HarmonySensorLab-delivery-1.0.0.zip', 'w', ZIP_DEFLATED) as archive:
    archive.write(source, source.name)
    archive.write(root / 'dist/README.md', 'README.md')
    for f in sorted((root / 'dist/packages').iterdir()):
        archive.write(f, 'packages/' + f.name)
    for f in sorted((root / 'docs').iterdir()):
        archive.write(f, 'docs/' + f.name)
    for name in ['validation-report.md', 'package-verification.json',
                 'device-connection-check-2026-11-08.json', 'device-status-managed.log']:
        archive.write(root / 'reports' / name, 'reports/' + name)
values = [hashlib.sha256(f.read_bytes()).hexdigest() + '  ' + f.name
          for f in sorted(archives.glob('*.zip'))]
(archives / 'SHA256SUMS.txt').write_text('\n'.join(values) + '\n')
print('Exported source and delivery. No signing configuration or credential files included.')
