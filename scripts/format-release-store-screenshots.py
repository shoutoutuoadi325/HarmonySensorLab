#!/usr/bin/env python3
"""Format verified Release captures without altering readings or stretching UI."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'reports/emulator-runtime/release-final-2026-11-10'
OUTPUT = ROOT / 'dist/store-submission-release-2026-11-10'
EXPECTED_HAPS = {
    'phone': '5b51c3e763d9dabb52f7defa5564061e6a5916b6f18c764d07b523319f07a2ee',
    'pc': '27711ea7c708579278f5f83d815ec7b8ab101e9e4b675327074d271aa91ff562',
    'tablet': '5b51c3e763d9dabb52f7defa5564061e6a5916b6f18c764d07b523319f07a2ee',
    'watch': '522b75ca70d6946c7b8ea39e244e96a5d1a066320d92dc3fd62e84d68448bf4f',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def format_capture(device, name, kind):
    source = SOURCE / device / (name + '.png')
    evidence_path = SOURCE / device / (name + '-evidence.json')
    evidence = json.loads(evidence_path.read_text())
    assert evidence['installedPackageSha256'] == EXPECTED_HAPS[device]
    assert sha(source) == evidence['screenshotSha256']
    original = Image.open(source).convert('RGB')
    if kind == 'phone-vertical':
        # Preserve every screenshot pixel, adding neutral side margins to 9:16.
        assert original.size == (1280, 2832)
        result = Image.new('RGB', (1593, 2832), '#F4F7FB')
        result.paste(original, (156, 0))
        assert result.crop((156, 0, 1436, 2832)).tobytes() == original.tobytes()
        transform = {'operation': 'neutral-side-padding', 'sourceOffset': [156, 0],
                     'leftPadding': 156, 'rightPadding': 157, 'scale': 1,
                     'crop': None, 'background': '#F4F7FB'}
        assert result.width * 16 == result.height * 9
    elif kind == 'pc-landscape':
        # The entire observed app window [515,281][2605,1675] remains inside.
        assert original.size == (3120, 2080)
        crop = (0, 100, 3120, 1855)
        result = original.crop(crop)
        transform = {'operation': 'crop-desktop-margins', 'crop': list(crop),
                     'retainedAppWindow': [515, 281, 2605, 1675], 'scale': 1}
        assert result.width * 9 == result.height * 16
    elif kind == 'tablet-landscape':
        assert original.size == (2880, 1920)
        result = original
        transform = {'operation': 'none', 'scale': 1, 'crop': None}
        assert result.width * 2 == result.height * 3
    elif kind == 'watch-square':
        assert original.size == (466, 466)
        result = original.resize((840, 840), Image.Resampling.LANCZOS)
        transform = {'operation': 'uniform-resize', 'scale': 840 / 466,
                     'crop': None, 'interpolation': 'Lanczos',
                     'reason': 'Console recommended square size'}
    else:
        raise ValueError(kind)
    dest = OUTPUT / 'screenshots' / device / (name + '.png')
    dest.parent.mkdir(parents=True, exist_ok=True)
    result.save(dest, optimize=True)
    assert dest.stat().st_size < (2 if device == 'watch' else 5) * 1024 * 1024
    return {
        'device': device, 'file': str(dest.relative_to(ROOT)),
        'source': str(source.relative_to(ROOT)), 'sourceSha256': sha(source),
        'sourceEvidence': str(evidence_path.relative_to(ROOT)),
        'installedPackageSha256': evidence['installedPackageSha256'],
        'sha256': sha(dest), 'width': result.width, 'height': result.height,
        'format': 'PNG', 'mode': 'RGB', 'bytes': dest.stat().st_size,
        'transformation': transform,
        'provenance': 'Official HarmonyOS emulator running current signed Release HAP; virtual callbacks are not physical measurements',
        'sensorReadingsEdited': False,
        'originalPixelsPreserved': kind != 'watch-square',
        'backendUploadVerified': False,
    }


if __name__ == '__main__':
    entries = []
    for device, names, kind in [
        ('phone', ['initial', 'live', 'privacy'], 'phone-vertical'),
        ('pc', ['home-prompt-dismissed', 'live', 'privacy'], 'pc-landscape'),
        ('tablet', ['initial', 'live', 'paused'], 'tablet-landscape'),
    ]:
        entries.extend(format_capture(device, name, kind) for name in names)
    watch_names = ['initial', 'live', 'paused', 'motion-denied']
    if all((SOURCE / 'watch' / (name + '-evidence.json')).exists() for name in watch_names):
        entries.extend(format_capture('watch', name, 'watch-square') for name in watch_names)
    manifest = {'application': '传感器观测', 'version': '1.0.0',
                'date': '2026-11-10', 'assets': entries,
                'status': 'Local formatted candidates; verify per-device console rules before upload'}
    (OUTPUT / 'assets-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps([{'device': a['device'], 'file': a['file'],
                       'size': [a['width'], a['height']], 'bytes': a['bytes']}
                      for a in entries], ensure_ascii=False, indent=2))
