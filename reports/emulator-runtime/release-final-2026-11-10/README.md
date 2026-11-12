# Final Release emulator evidence

Prepared on 2026-11-10. This directory contains actual current Release HAP installation and runtime screenshots. See `runtime-candidate-manifest.json` and `status-for-audit.txt` for assessed results and untested items. The initial `preparation-status.json` is a historical preparation record.

The helper `hdc_release_capture.py` uses only the installed official HDC and device `uitest` CLI. It never starts or interacts with native desktop/browser apps, never changes sensor values, and never installs a Debug fallback. Original PNGs, layout JSON, command outcomes and exact installed HAP SHA-256 associations are saved per device.

## Current discovery

The default HDC client returned `Connect server failed`; no listening HDC server was present. A separate managed foreground HDC server was then started at `127.0.0.1:8710`. Reuse this live server. Do not restart it because a query times out. `discovery/current.json` records the latest actual target listing. An empty target list means no currently connected device, not completed or failed emulator validation.

## Reproducible commands

Start a named official local emulator in DevEco Studio UI. Read its current connection key from HDC discovery and verify the device identity matches the intended emulator before installation. Use the actual current connection key in place of `<target>`; never assume a historical port remains valid.

```sh
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py discover
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone identity
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone install
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone launch
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone --name 01-initial capture
```

Select `phone`, `tablet`, `pc` or `watch` to choose the verified default, default, pc or wearable Release HAP. If Release installation fails, retain the actual error. A prior Debug app may be removed only after its signer is verified to prevent replacement; a Release rejection must not be relabeled as Debug runtime verification.

Inspect the latest layout output before each action. For a visible enabled button, use `click --text` with the exact current text. Start observation, capture the actual callback/empty-state screen, select frequency, pause/resume and clear charts. Scroll only within bounds observed in the current layout. Capture three distinct meaningful app screens per device, rather than duplicate captures of one state.

```sh
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone --name 02-observation --text '开始观测' click
python3 reports/emulator-runtime/release-final-2026-11-10/hdc_release_capture.py --target '<target>' --device phone --name 03-paused --text '暂停采集' click
```

Open `本机数据与隐私`, verify full policy/contact text and dismissal, and test the online policy system-browser fallback. For foreground control, send `home`, relaunch and verify collection remains paused until explicit resume. The helper uses the documented `Home` key name. The earlier `KEYCODE_HOME` failure is retained in the phone command log; `Home` then returned `No Error` and the launcher layout was verified.

All captures are official virtual-emulator evidence, not physical sensor measurements, wearable crown testing or store approval. Backend screenshot formatting remains a separate step: preserve originals and record any resize/letterboxing, never fabricate sensor values or claim the original pixels are unchanged after formatting.
