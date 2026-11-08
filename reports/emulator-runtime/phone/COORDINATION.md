# Phone runtime findings needing parent coordination

Phone app pause state has changed between my targeted captures without a matching phone click. This occurred after denying motion and again while testing clear history. Other Emulator instances are being started concurrently. Suspect Emulator -instance scenario CLI does not target HDC reliably with multiple connected devices; all my phone UI actions now use explicit hdc -t 127.0.0.1:12001 shell uitest commands. Please ensure all other device actions use explicit HDC targets.

Frequency popup is visible in the uitest dump but gone by the screenshot seconds later; selecting 1 Hz after capture did not change the setting. Could be parent interaction on the phone, or high frequency snapshot updates resetting the Select popup. Please avoid any phone interaction while this phone suite runs. If still reproducible, isolate controls' intervalMs state from live sensor snapshot updates so popup state is stable.
