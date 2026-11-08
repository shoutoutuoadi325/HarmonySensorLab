# Emulator matrix summary

Official DevEco Emulator CLI and HarmonyOS SDK hdc/uitest were used. Phone/foldable handled by root agent. This matrix covers four other kinds.

| Kind | Runtime | Screen/density | Public local instances | Evidence |
|---|---|---|---|---|
| Wearable | HarmonyOS7.0.0 API26 |466×466 /320|9|Ordinary unsigned then HarmonyOS-signed install/start; controls,values,chart; final arrow contrast screenshot|
| PC/2in1 |HarmonyOS7.0.0 API26|3120×2080 /304|7|Initial default user unlock; unsigned/signed install/start; floating2 columns/maximized3;pause|
| Tablet |HarmonyOS7.0.0 API26|2880×1920 /320|9|Unsigned/signed install/start;landscape3 columns/portrait2 after emulator orientation-lock off|
| TV |HarmonyOS6.1.1 API24|3840×2160 /480|1|Unsigned/signed install/start;environment-light virtual callbacks;final white dark-button text/dark arrow;Enter start works|

Every reported reading is an emulator virtual callback, even when metadata calls an instance local/non-mock. No hardware behavior, precision, signed production install or market approval inferred. TV -sensor scenario command explicitly unsupported.

TV final explicit frequency/axis Buttons and Toggle key handler are verified with DPAD directions and CENTER: starts, chooses10Hz, selectsinfrared curve, disables/re-enables sensor. Focus transfer is verified. Historical nativeSelect/Toggle confirmation and contrast issues were resolved. Actual physical remote hardware mapping remains unverified.

Per-kind observations.md records exact scenario details and tested-final-signed-sha256.txt records current tested signed HAP hash. Historical screenshot filenames correspond to earlier packages; files named final- record latest evidence.
