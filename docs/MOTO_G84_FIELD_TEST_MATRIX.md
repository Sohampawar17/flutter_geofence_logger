# Moto G84 5G field-test matrix

Run this matrix on the production-signed build against a staging Frappe site. Do not use production attendance records.

| ID | Preconditions | Steps | Expected result | Actual / evidence | Status |
|---|---|---|---|---|---|
| FG-01 | Signed in; assigned fence; precise + background location granted | Cross outside→inside, then inside→outside with app open | One ordered ENTER and EXIT; both persist before upload | Not executed | NOT TESTED |
| BG-01 | Same; app in background | Cross both boundaries | Events persist and eventually sync | Not executed | NOT TESTED |
| LK-01 | Same; screen locked | Cross both boundaries | Events persist; delivery may be delayed by Android | Not executed | NOT TESTED |
| RC-01 | Same | Remove app from Recents; cross both boundaries | Native geofence worker still records events | Not executed | NOT TESTED |
| RB-01 | Fence registered | Reboot; do not open app; cross boundary | boot receiver restores fence and event is recorded | Not executed | NOT TESTED |
| OF-01 | Fence registered | Enable airplane mode; cross; restore network | Event remains pending, then syncs once with same event ID | Not executed | NOT TESTED |
| API-01 | Staging API can be stopped | Stop API; create event; restart API | Retry/backoff; no event loss or duplicate | Mocked only | NOT TESTED |
| PM-01 | Tracking healthy | Revoke background permission | Health says permission blocked; no false “healthy” state | Not executed | NOT TESTED |
| LS-01 | Tracking healthy | Turn Location off, then on; reopen app | Employee is alerted; registrations reconcile after restore | Not executed | NOT TESTED |
| BS-01 | Tracking healthy | Enable Battery Saver/restricted battery; cross boundary | Status warns restriction; delayed delivery is acceptable | Not executed | NOT TESTED |
| FF-01 | Tracking healthy | Android Settings → Force stop; cross boundary; reopen app | No tracking while force-stopped; recovery only after reopen | Android restriction | NOT SUPPORTED |
| JT-01 | Near fence boundary | Cross rapidly several times | Genuine alternating transitions retained; consecutive same-state callbacks deduplicated | Unit policy tested only | NOT TESTED |
| OO-01 | Staging backend | Upload delayed/out-of-order attendance | Raw event stored; ambiguous/finalized attendance marked Review | Automated backend runtime unavailable | NOT TESTED |

## Evidence commands

```powershell
adb shell dumpsys package com.geopulse.geofence_logger
adb shell dumpsys jobscheduler | Select-String geopulse -Context 3,8
adb logcat -s NativeGeofenceBroadcastReceiver NativeGeofenceBackgroundWorker WorkManager
adb shell run-as com.geopulse.geofence_logger ls databases
adb shell run-as com.geopulse.geofence_logger cp databases/geofence_events.db /sdcard/geofence-events-test.db
adb pull /sdcard/geofence-events-test.db
sqlite3 geofence-events-test.db "select event_id,event_type,event_timestamp,sync_status,retry_count,last_error from geofence_events order by event_timestamp;"
```

For every event, match the same `event_id`, timestamp, type, employee, device registration, and server acknowledgement in Frappe. Record logcat timestamps, SQLite rows, Frappe document names, and recovery delay in the Actual/evidence column.
