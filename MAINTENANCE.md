# Maintenance

Monthly: review failed sync/diagnostics, audit logs, TLS expiry, backups, registrations, and revoked employees. Quarterly: run `flutter pub outdated`, review plugin changes, test supported Android/OEM versions, rotate credentials, restore a Frappe backup, and review retention.

Every release: increment version/build, run format/analyze/tests/APK build, inspect manifest merge, migrate from the prior database, execute the device matrix, sign with a production key outside source control, and maintain Play background-location disclosure/privacy policy.

Kotlin 2.2 is required by the current `battery_plus` and `device_info_plus` Android artifacts. Re-test `native_geofence`, the MethodChannel, native WorkManager, and encrypted preferences whenever Kotlin, AGP, or Flutter is upgraded even though older geofence-plugin documentation references Kotlin 1.9.25.

Native geofencing saves battery versus GPS but has OS latency. Custom Kotlin offers control at higher maintenance cost. SQLite is suitable for durability; database encryption may be added for high-risk deployments. WorkManager beats manual-only sync but is not exact-time. Multiple configurable zones improve flexibility but need an organizational count/radius policy.

Future options: short-lived server device tokens, safe certificate pinning/rotation, admin-pushed assignments, encrypted exports/database, telemetry dashboards, and disposable-site integration tests.
