# Features

| Feature | Source/trigger | Conditions and failure behavior | Verification |
|---|---|---|---|
| Create/edit zone | `AppController.saveGeofence`, editor | Valid input/permissions; edit restores prior registration if replacement fails | validation + physical test |
| Enable/disable/remove | controller actions | Native monitoring removed; historical/unsynced records preserved | physical test |
| ENTER/EXIT | `nativeGeofenceCallback` | Native callback only; atomic insert; error diagnosed | transition tests + walk test |
| Duplicate/jitter control | `TransitionPolicy`, `geofence_state` | same/out-of-order/45-second jitter suppressed | unit tests |
| Offline queue | SQLite sync status | pending survives outages/restarts | airplane-mode test |
| Background sync | WorkManager | constrained, exponential retry; interrupted work recovered | outage test |
| Enrollment/API | Frappe endpoints | authenticated and server-authorized device | Frappe tests |
| Diagnostics | Health UI/Kotlin channel | unavailable values show unknown | widget/device test |
| Retention | explicit UI action | deletes only old synced events | database test |

Background-event state remains null because the plugin does not reliably expose foreground/background state. Accuracy is nullable and comes from a last-known fix when available.
