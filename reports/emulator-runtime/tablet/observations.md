# Tablet emulator observations

- Official HarmonyOS7.0.0 API26 Tablet image, default 2880×1920 density320. Ordinary unsigned default Debug HAP installed and started successfully.
- Started observation. 9 public local sensor instances enumerated; live accelerometer in landscape X9.800/Y0.000/Z0.000 m/s², other values and charts visibly rendered. All are emulator virtual callbacks.
- Landscape renders 3 card columns without overlap.
- Initial CLI rotation returned success but OS orientation lock held dimensions. Opened emulator Control Center and disabled visible Orientation lock, then rotated left through official CLI. Screenshot proved 1920×2880 portrait and tree proved 2 columns; cards and text reflowed.
- Saved welcome, landscape and portrait screenshot/UI JSON evidence. Official SDK uitest used with specific target127.0.0.1:12005.
- No physical tablet/pen/keyboard sensor validation claimed.
- 22:03 final signed Debug HAP installed/launched successfully after uninstalling prior unsigned; current final-observation.png/layout shows9 instances and3 columns in landscape. Exact hash in tested-final-signed-sha256.txt.
- Latest22:11 color/arrow package ordinary install+launch passed again; final-color-welcome.png and layout show actual current app. Prior final-observation.png is22:03 package; current hash refreshed.
- Final22:23 signed file installed+launched and current welcome screenshot captured again after TV explicit-control implementation; tested-final-signed-sha256.txt now matches delivered file exactly.
