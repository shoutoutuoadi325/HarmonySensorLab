# Wearable emulator observations

- Official HarmonyOS 7.0.0 API26 wearable image, default 466×466 density320, installed existing unsigned Debug HAP normally and launched successfully.
- Welcome start button is initially below the viewport; a single scroll up makes it reachable.
- Started observation successfully (screenshot Screenshot_2026-11-08T214253.png). Controls wrap to two buttons on 185vp inner width, vertically scrollable.
- **UI defect:** frequency Select text/arrow appear white on the near-white background and are difficult to read; screenshot proves. Explicit Select fontColor/backgroundColor needed, likely affects other products too.
- First post-start UI tree extraction returned “Analysis failed”; saved command log. Must retry before deriving new widget IDs.
- Emulator readings must be labeled virtual; no physical wearable evidence.
- Official Emulator UI tree fails after observation (“Analysis failed” / “HDC not connected”), despite hdc target Connected. Official SDK `uitest dumpLayout -b com.personal.harmonysensorlab` works and captured visible UI as JSON.
- App enumerates 9 local public instances. Accelerometer displays “实时” and X=0.000, Y=9.800, Z=0.000 m/s² from emulator callbacks; these are virtual emulator values.
- Final signed Debug HAP installed successfully after removing unsigned test app; launched and enumerated9. Signed screenshots prove frequency text now dark and readable, accelerometer values0/9.8/0 and chart readable. White Select arrow remains low contrast, but text and selected value visible.
- 22:03 updated signed package retested successfully: install-final-signed.log,launch-final-signed.log,final-controls.png; exact current hash in tested-final-signed-sha256.txt.
- Latest22:11 color/arrow package retested: final-controls.png now proves dark arrow and readable frequency/dark-button contrast. Current hash refreshed.
- Latest22:17 focus-transfer-source signed HAP retested and current hash refreshed; final-controls.png again confirms dark frequency arrow and white Pause text.
