# Harmony Sensor Lab Privacy Policy

Version: 1.0.0. Last updated: November 10, 2026. This policy takes effect when the application is first publicly released.
Developer: 张之麒 (Zhiqi Zhang). Contact: zhiqizhangg@gmail.com.
Bundle name: com.personal.harmonysensorlab.

Harmony Sensor Lab displays values and recent charts provided by public sensor APIs on your current device. Available sensors and data depend on the hardware, operating system and permissions.

## Data and purposes

The app reads local sensor names and capabilities, ordinary motion, magnetic-field, orientation, light, pressure, proximity and other supported sensor callbacks, and their receipt times. These data are used only to display values and charts on your device. Step data are read only after you choose motion authorization and grant the system permission. The cumulative step period is defined by the device system; the app does not label it as today's steps.

This version does not collect heart rate, blood oxygen, ECG, skin temperature or other health measurements, and does not access Huawei Health databases. It does not obtain external watch sensor data through a phone. It does not request location, camera, microphone, contacts or Internet access, and does not collect accounts, advertising identifiers or device serial numbers.

## Storage, retention and sharing

Values and charts remain in the current process memory on your device. Each chart retains at most 240 actual samples spanning no more than 60 seconds; at high rates the retained period may be shorter. While collection is paused or no new callbacks arrive, the existing chart remains in device memory until you clear charts, refresh available sensors, or the process ends. The app does not write samples to files or a database, upload them, or transfer them to the developer, third parties or another device.

Collection runs in the foreground. Pausing, disabling a sensor, leaving the observation page or moving the app into the background stops the relevant subscriptions. Clearing charts removes their history. The operating system terminating the process removes the in-memory records. Frequency and collection state are retained only during the current running session.

The app contains no account service, advertising, analytics SDK or cloud synchronization. It does not sell or share data. Development tools may display technical error information without raw sensor readings. Operating-system logs are governed by the operating system's own rules.

## Permissions and choices

- ohos.permission.ACCELEROMETER: public local accelerometer-related sensors; granted by the system at installation. You may pause collection.
- ohos.permission.GYROSCOPE: public local gyroscope-related sensors; granted by the system at installation. You may pause collection.
- ohos.permission.ACTIVITY_MOTION: system step and walking-detection data after you choose motion authorization; requested at runtime. Denying or revoking it stops that feature while other available ordinary sensors remain usable.

You can pause collection, change the requested frequency, clear charts, close the app, or manage motion permission in system settings. Unsupported sensors, missing permissions, invalid data and missing callbacks are displayed as distinct states; unavailable readings are not replaced with invented zero values. The developer receives no data and cannot remotely inspect or delete local records.

## Online privacy policy

When you choose “Online privacy policy”, the app opens this app’s policy-hosting website in the system browser. The system browser handles the network requests required to visit that website; the website and operating system process normal website-access information under their own rules. The app does not append sensor readings, callback receipt times, or user or device identifiers to the policy URL. Opening the policy does not change the local, in-memory processing of sensor data. If your device cannot open the system browser, the full policy remains available inside the app.

## Safety and policy changes

Readings are intended for observing device API output. They must not be used for medical diagnosis, health conclusions or safety-critical decisions. Parents or guardians should understand this policy and permission use when minors use the app. If future versions add health collection, storage, export, networking or third-party components, the policy will be updated and applicable permission obtained before those features are used.

Contact zhiqizhangg@gmail.com with privacy questions or complaints. Privacy complaints will be handled within 15 working days of receipt.
