# Testing

Run:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
bench --site SITE run-tests --app geofence_logger
```

Unit tests cover location/radius/HTTPS validation and transition matrix behavior including initial state, duplicate, jitter, and out-of-order callbacks. Widget tests cover metrics and nullable event details. Frappe tests cover idempotency and invalid types.

## Physical Android checklist

On a Google-certified device, create a 200 m zone away from its boundary. Verify initial outside creates no EXIT; cross inward for one ENTER; remain inside for none; cross outward after debounce for one EXIT. Repeat screen locked, minimized, process swiped away, reboot, airplane mode, Wi-Fi without internet, server outage, permission revoke, location off/on, battery saver, authentication failure, and geofence edit/disable. Confirm local rows survive and later sync once.

Record force-stop, missing/outdated Play Services, OEM restrictions, and clock changes as platform outcomes. Test Android API 29, 31, 33, 34, and the current target before release.
