# Database Schema

Database `geofence_events.db`, version 4:

- `geofences`: configuration, assignment reference, enabled state, coordinates/radius/timestamps.
- `geofence_events`: event payload and sync/retry/error/server metadata with CHECK constraints.
- `geofence_state`: authoritative UNKNOWN/INSIDE/OUTSIDE and callback/event times.
- `device_registration`: reserved local enrollment metadata.
- `diagnostics`: redacted operational messages.

Indexes cover sync/time, geofence/time, and diagnostics/time. Migration creates the v4 schema and copies legacy `locations`/`events` without deleting them, including databases lacking `assigned_to`.

Event/state changes are one transaction. Batch claiming atomically changes rows to `syncing`; work older than 15 minutes is recovered. Partial acknowledgements update individual rows. Retention deletes only explicitly selected old `synced` rows.
