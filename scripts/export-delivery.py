#!/usr/bin/env python3
"""Export auditable source and delivery without changing local signing configuration."""
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
profile = json.loads((root / 'build-profile.json5').read_text())
signing_configs = profile['app'].get('signingConfigs', [])


def passwords_in(value):
    """Keep signing passwords in memory only, to reject accidental copies in reports."""
    result = []
    if isinstance(value, dict):
        for key, item in value.items():
            if 'password' in key.lower() and isinstance(item, str) and item:
                result.append(item)
            else:
                result.extend(passwords_in(item))
    elif isinstance(value, list):
        for item in value:
            result.extend(passwords_in(item))
    return result


signing_passwords = passwords_in(signing_configs)
for private_signing in sorted((root / '.signing').rglob('*.json')):
    signing_passwords.extend(passwords_in(json.loads(private_signing.read_text())))
# Quoted short passwords avoid mistaking download byte counts for credentials.
signing_tokens = {json.dumps(password, ensure_ascii=False).encode('utf-8') for password in signing_passwords}
signing_tokens.update(password.encode('utf-8') for password in signing_passwords if len(password) >= 12)
profile['app']['signingConfigs'] = []
for product in profile['app'].get('products', []):
    product.pop('signingConfig', None)
source_profile = (json.dumps(profile, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def check_export_file(file):
    if file.suffix.lower() in {'.p12', '.p7b', '.cer', '.keystore', '.pem', '.key', '.jks', '.pfx'}:
        raise SystemExit('Credential files must not be exported: ' + str(file.relative_to(root)))
    # The original profile is replaced with sanitized bytes rather than copied.
    if file == root / 'build-profile.json5':
        return
    if signing_tokens:
        contents = file.read_bytes()
        if any(token in contents for token in signing_tokens):
            raise SystemExit('Signing password found in export input; sanitize this file: ' + str(file.relative_to(root)))


archives = root / 'dist/archives'
archives.mkdir(parents=True, exist_ok=True)
source = archives / 'HarmonySensorLab-source-1.0.0.zip'


def exportable(file):
    return file.is_file() and '__pycache__' not in file.parts and file.name != '.DS_Store' and file.suffix != '.pyc'


folders = ['AppScope', 'entry/src', 'docs', 'scripts', 'tests', 'reports', 'hvigor']
files = ['README.md', '.gitignore', 'build-profile.json5', 'hvigorfile.ts', 'oh-package.json5',
         'entry/build-profile.json5', 'entry/hvigorfile.ts', 'entry/oh-package.json5']
for folder in folders:
    files.extend(str(f.relative_to(root)) for f in sorted((root / folder).rglob('*')) if exportable(f))
delivery_files = [(f, 'packages/' + f.name) for f in sorted((root / 'dist/packages').iterdir()) if exportable(f)]
delivery_files.extend((f, 'docs/' + str(f.relative_to(root / 'docs')))
                      for f in sorted((root / 'docs').rglob('*')) if exportable(f))
delivery_files.extend((f, 'reports/' + str(f.relative_to(root / 'reports')))
                      for f in sorted((root / 'reports').rglob('*')) if exportable(f))
first_release_assets = root / 'dist/store-submission-first'
if first_release_assets.is_dir():
    delivery_files.extend((f, 'store-submission-first/' + str(f.relative_to(first_release_assets)))
                          for f in sorted(first_release_assets.rglob('*')) if exportable(f))
for file in {root / name for name in files} | {f for f, _ in delivery_files} | {root / 'dist/README.md'}:
    check_export_file(file)
with ZipFile(source, 'w', ZIP_DEFLATED) as archive:
    for filename in sorted(files):
        if filename == 'build-profile.json5':
            archive.writestr('HarmonySensorLab/' + filename, source_profile)
        else:
            archive.write(root / filename, 'HarmonySensorLab/' + filename)
with ZipFile(archives / 'HarmonySensorLab-delivery-1.0.0.zip', 'w', ZIP_DEFLATED) as archive:
    archive.write(source, source.name)
    archive.write(root / 'dist/README.md', 'README.md')
    for f, archive_name in delivery_files:
        archive.write(f, archive_name)
values = [hashlib.sha256(f.read_bytes()).hexdigest() + '  ' + f.name
          for f in sorted(archives.glob('*.zip'))]
(archives / 'SHA256SUMS.txt').write_text('\n'.join(values) + '\n')
print('Exported source and delivery with sanitized source profile and emulator evidence. Local signing configuration unchanged.')
