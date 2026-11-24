# GeoPulse

Android-only Flutter geofencing with native ENTER/EXIT callbacks, durable SQLite storage, encrypted Frappe credentials, and WorkManager synchronization.

## Quick start

1. Run `flutter pub get`, `flutter analyze`, and `flutter test`.
2. Connect a Google-certified Android device and run `flutter run`.
3. Add a location and grant precise foreground plus “Allow all the time” location access.
4. Install `frappe_app/geofence_logger`, create least-privilege API credentials, enroll the device, and configure the HTTPS URL in the app.

The app does not use continuous tracking. Native geofencing determines transitions; a last-known fix only enriches a callback when available. Unsynchronized records are never automatically deleted.

Android may delay callbacks/jobs. Force-stop prevents recovery until the app is opened. See `TESTING.md` and `TROUBLESHOOTING.md`.

Employee attendance supports authenticated Check In and Check Out, accurate-location validation, offline local storage, device telemetry, and an HR-reviewable Frappe audit log. See `USER_MANUAL.md` for employee and deployment instructions.

Documentation: `ARCHITECTURE.md`, `FEATURES.md`, `VALIDATIONS.md`, `DATABASE_SCHEMA.md`, `FRAPPE_API.md`, `ANDROID_PERMISSIONS.md`, `TESTING.md`, `TROUBLESHOOTING.md`, and `MAINTENANCE.md`.
