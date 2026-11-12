#!/usr/bin/env python3
"""Exercise the actual signing script in isolated projects with synthetic credentials."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DebugSigningScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sensor-signing-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ('scripts', '.signing', 'reports', 'dist/packages'):
            (self.root / folder).mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/build-debug-signed.py', self.root / 'scripts/build-debug-signed.py')
        self.original = (json.dumps({'app': {'signingConfigs': [], 'products': [
            {'name': name} for name in ('default', 'pc', 'wearable', 'tv')]}}) + '\r\n').encode()
        self.profile = self.root / 'build-profile.json5'
        self.profile.write_bytes(self.original)
        self.profile.chmod(0o644)
        (self.root / '.signing/deveco-signing.json').write_text(json.dumps([{
            'name': 'fixture', 'material': {'storePassword': 'stub9', 'keyPassword': 'stub9'}}]))
        build = self.root / 'scripts/build.sh'
        build.write_text('''#!/usr/bin/env python3
import json
import os
import signal
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
profile = root / 'build-profile.json5'
assert profile.stat().st_mode & 0o777 == 0o600
assert json.loads(profile.read_text())['app']['signingConfigs'][0]['name'] == 'fixture'
print('Synthetic build password: stub9', flush=True)
mode = (root / 'test-mode').read_text()
if mode == 'failure':
    sys.exit(9)
if mode == 'interrupt':
    os.kill(os.getppid(), signal.SIGTERM)
    sys.exit(0)
product = sys.argv[1]
target = root / f'entry/build/{product}/outputs/{product}/entry-{product}-signed.hap'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(b'synthetic package used only in an isolated test')
''')
        build.chmod(0o755)

    def run_case(self, mode):
        (self.root / 'test-mode').write_text(mode)
        return subprocess.run(['python3', str(self.root / 'scripts/build-debug-signed.py')],
                              cwd=self.root, capture_output=True, text=True, timeout=15)

    def assert_restored(self):
        self.assertEqual(self.profile.read_bytes(), self.original)
        self.assertEqual(self.profile.stat().st_mode & 0o777, 0o644)
        self.assertFalse((self.root / '.signing/build.lock').exists())

    def test_success_restores_bytes_mode_and_redacts_short_password(self):
        result = self.run_case('success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_restored()
        self.assertEqual(len(list((self.root / 'dist/packages').glob('*.hap'))), 4)
        for log in (self.root / 'reports').glob('*.log'):
            self.assertNotIn('stub9', log.read_text())
            self.assertIn('[private signing value]', log.read_text())

    def test_build_failure_restores_profile_and_does_not_export_package(self):
        result = self.run_case('failure')
        self.assertNotEqual(result.returncode, 0)
        self.assert_restored()
        self.assertFalse(list((self.root / 'dist/packages').glob('*.hap')))
        self.assertNotIn('stub9', (self.root / 'reports/build-debug-default-signed.log').read_text())

    def test_termination_restores_profile_and_releases_lock(self):
        result = self.run_case('interrupt')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('restoring portable signing configuration', result.stderr)
        self.assert_restored()

    def test_existing_lock_is_rejected_before_reading_profile(self):
        lock = self.root / '.signing/build.lock'
        lock.write_text('active build fixture')
        self.profile.write_text('deliberately invalid while another build owns the lock')
        result = self.run_case('success')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FileExistsError', result.stderr)
        self.assertNotIn('JSONDecodeError', result.stderr)
        self.assertEqual(lock.read_text(), 'active build fixture')
        self.assertEqual(self.profile.read_text(), 'deliberately invalid while another build owns the lock')


if __name__ == '__main__':
    unittest.main(verbosity=2)
