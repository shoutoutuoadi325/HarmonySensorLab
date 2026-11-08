# PC emulator observations

- Official HarmonyOS 7.0.0 API26 2in1 image, 3120×2080 density304.
- First install failed code301 user not exist; first launch was locked. Selected visible default emulator user avatar, unlocked without password. Ordinary unsigned HAP install then succeeded and ability started successfully. Logs preserve before/after.
- Dismissed initial “Add to home screen?” dialog with Never add in this disposable emulator.
- App enumerates 7 public local sensor instances. At initial floating window, cards render in 2 columns; accelerometer callback X0.000/Y9.800/Z0.000 m/s², gyroscope 0/0/0. These are emulator virtual values.
- Pause click changed button to 继续采集, visible card state to 已暂停 and caption “已暂停；保留的是暂停前的数值”. Paused snapshot captured.
- Double-clicked window title bar to maximize. Layout automatically changed to 3 columns; screenshot and tree captured.
- SDK uitest dumpLayout and screenCap used because Emulator screenshot command reported success without creating a PC PNG. All actions target only 127.0.0.1:12004.
- No hardware PC sensor validation, no signature eligibility or keyboard/physical 2in1 hinge validation claimed.
- 22:03 final signed Debug HAP installed/launched successfully (after uninstall prior unsigned). Final current screenshot shows2-column floating window with7 local sensor instances. Exact hash in tested-final-signed-sha256.txt.
- Latest22:11 color/arrow package ordinary install+launch passed again; final-color-welcome.png shows actual current app. Prior final-observation.png is22:03 package; current hash refreshed.
- Final22:23 signed file installed+launched and current welcome screenshot captured again after TV explicit-control implementation; tested-final-signed-sha256.txt now matches delivered file exactly.
