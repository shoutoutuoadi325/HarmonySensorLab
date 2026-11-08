# TV emulator observations

Final package: current HarmonyOS-signed TV Debug HAP; exact hash in tested-final-signed-sha256.txt. Official HarmonyOS6.1.1 API24 image,3840×2160 density480.

## Final verification

- Ordinary signed HAP installation and EntryAbility launch succeeded; runtime API24 queried via hdc.
- DPAD_CENTER2016 starts from focused welcome Button; focus transfers to Pause.
- DPAD_RIGHT then CENTER opens explicit frequency choices; current5Hz is focused. RIGHT then CENTER selects10Hz and transfers focus back to frequency control. final-choices-layout.json and final-frequency-button-layout.json preserve this.
- DPAD_DOWN traverses hardware-details row to explicit axis Buttons. CENTER selects infrared; native tree confirms infrared background becomesdark102C41 and other axes remainpaleE5EEF5. final-axis-selected-layout.json preserves this.
- DOWN focuses Toggle; CENTER changes checkedtrue→false and UI “已关闭/此传感器已关闭/采集已关闭”. Another CENTER re-enables. final-toggle-layout.json and logs preserve this.
- Final screenshot shows10Hz, dark arrow, white Pause text and selected infrared Button.
- API enumerates1 public local environment-light instance; live callbacks lx0.000/cct4000.000/infrared0.000 are emulator virtual values. Optional fields remain explicitly qualified.
- Official Emulator -sensor command is unsupported onTV; failure log preserved.

## Earlier findings

Historical unsigned/earlier signed packages showed black text on darkButtons, white arrows, lost focus afterwelcome, and nativeSelect/Toggle CENTER failures. Those prompted implementation fixes and were resolved by final explicitControls/focusTransfer tests above. Earlier JSON/screenshot files are historical; final-frequency-button/axis-selected/toggle files represent final controls. Earlier nativefrequency popup tests usedEnter; final frequency/axes useexplicitButtons and CENTER.

No physical TV sensor precision, actual remote hardware mapping, market approval or production-signing eligibility is inferred from emulator evidence.
