# Architecture

`lib/app` contains composition, Material screens, and `AppController` state. `lib/core` contains constants, validation, errors, and Android readiness checks. Feature folders own geofencing, events/SQLite, device metadata, and synchronization. `frappe_app` is a deployable server package.

Event flow: Android GeofencingClient → background callback → nullable device/last-known location snapshot → atomic state evaluation/event insert → notification. A Flutter MethodChannel configures native Kotlin WorkManager; the Kotlin worker claims the same SQLite queue, sends batch HTTPS requests, and applies per-event acknowledgements. This avoids a second Dart background-engine bridge.

Native callbacks are authoritative; distance never creates a transition. UNKNOWN→INSIDE records ENTER. UNKNOWN→OUTSIDE establishes state without inventing EXIT. Repeated states, out-of-order callbacks, and opposite callbacks inside 45 seconds are suppressed and diagnosed.

SQLite is the source of truth and survives UI/process recreation. Background entry points create isolate-safe dependencies. Native geofencing is battery-efficient but Android controls timing. The plugin reduces Kotlin lifecycle code but must be compatibility-tested. WorkManager is durable, not exact-time. Multiple geofences are supported; keep deployments below Android's platform limit.
