# Android Permissions

The manifest declares Internet, coarse/fine/background location, notifications, boot completed, wake lock, and plugin service permissions. Minimum API 26 is required by the installed native-geofence plugin; background location is required from API 29.

The UI requests precise foreground location first, then “Allow all the time”, then notifications. A monitoring explanation is visible before saving. Status is rechecked on resume.

The plugin registers native GeofencingClient regions and a boot receiver. App code does not start a permanent foreground service. A MethodChannel schedules native Kotlin WorkManager jobs; credentials are stored with AndroidX EncryptedSharedPreferences and the worker updates the SQLite queue transactionally. Kotlin also reports Play Services and battery-optimization status; exemption is recommended, not silently requested.

Force-stop cannot recover until launch. Disabled location, revoked permission, missing Play Services, battery saver, and OEM restrictions can prevent or delay work. Exact timing is never guaranteed.
