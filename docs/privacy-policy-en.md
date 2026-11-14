# Harmony Sensor Lab Privacy Policy

Version: 1.0.1. Last updated: November 14, 2026. This policy takes effect with app version 1.0.1.
Developer: 张之麒 (Zhiqi Zhang). Contact: zhiqizhangg@gmail.com.
Bundle name: com.personal.harmonysensorlab.

Harmony Sensor Lab displays values and recent charts provided by public sensor APIs on your current device. Available sensors and data depend on the hardware, operating system and permissions.

## Data and purposes

After you agree to this policy and start observation, the app uses system sensor APIs to list local sensor names and capabilities and subscribe to supported sensors in the foreground. It reads three-axis acceleration, gyroscope angular velocity and three-axis gravity components, plus supported readings or events such as magnetic field, orientation, light, pressure, proximity and wear detection, and their receipt times. The app uses them to display values and draw recent charts on your device. The gravity sensor reports gravity along the device's X, Y and Z axes and requires no separate runtime permission.

The app can read cumulative step count and step detection events during observation after the system grants motion permission. The app requests this permission only when you select “Allow motion.” The system defines the period covered by the cumulative count.

This version does not collect heart rate, blood oxygen, ECG, skin temperature or other health measurements, and does not access Huawei Health databases. It does not obtain external watch sensor data through a phone. It does not request location, camera, microphone, contacts or Internet access, and does not collect accounts, advertising identifiers or device serial numbers.

## Storage, retention and sharing

Each chart retains up to 240 samples spanning up to 60 seconds. Readings and charts remain in the app process memory on your device. They are never written to files, databases or cloud storage, or sent to the developer, third parties or another device. Pausing, moving the app into the background or leaving the observation page stops collection. Clearing charts, refreshing sensors, withdrawing consent or ending the process clears chart history. The frequency and observation state last for the current session. The app stores your choice for the current privacy policy version on your device so that it can honor your choice the next time it starts.

The app contains no account service, advertising, analytics SDK or cloud synchronization. It does not sell or share data. Development tools may display technical error information without raw sensor readings. Operating-system logs are governed by the operating system's own rules.

## Permissions and choices

- ohos.permission.ACCELEROMETER: public local accelerometer-related sensors; granted by the system at installation. You may pause collection.
- ohos.permission.GYROSCOPE: public local gyroscope-related sensors; granted by the system at installation. You may pause collection.
- ohos.permission.ACTIVITY_MOTION: reads your motion state to display cumulative step count and step detection events. The app requests permission when you choose to grant it. Denying or revoking it stops these readings while other available ordinary sensors remain usable.

You can decline the privacy policy at the first prompt or select “Withdraw consent” in “On-device privacy.” After you decline or withdraw, you can still read the policy, and observation stays off. Withdrawing stops collection, clears observation records from device memory and prevents the app from requesting motion permission until you agree again. You can also manage motion permission in system settings. The developer receives no data and cannot remotely inspect or delete local records.

## Online privacy policy

When you choose “Online privacy policy”, the app opens this app’s policy-hosting website in the system browser. The system browser handles the network requests required to visit that website; the website and operating system process normal website-access information under their own rules. The app does not append sensor readings, callback receipt times, or user or device identifiers to the policy URL. Opening the policy does not change the local, in-memory processing of sensor data. If your device cannot open the system browser, the full policy remains available inside the app.

## Safety and policy changes

Readings are intended for observing device API output. They must not be used for medical diagnosis, health conclusions or safety-critical decisions. Parents or guardians should understand this policy and permission use when minors use the app. If future versions add health collection, storage, export, networking or third-party components, the policy will be updated and applicable permission obtained before those features are used.

Contact zhiqizhangg@gmail.com with privacy questions or complaints. Privacy complaints will be handled within 15 working days of receipt.
