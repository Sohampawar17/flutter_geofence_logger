# Frappe / ERPNext API

Install the package under `frappe_app/geofence_logger`:

```bash
bench --site SITE install-app geofence_logger
bench --site SITE migrate
bench restart
```

Use a dedicated API user. Enrollment administrators need `Geofence Manager`; apply least privilege and never share secrets across unrelated employees.

- `POST /api/method/geofence_logger.api.enroll_device`: manager-only; binds installation UUID to authenticated API user and optional server-validated Employee.
- `POST /api/method/geofence_logger.api.ingest_events`: accepts `{ "events": [...] }`, 1–100 records. It validates payloads and requires an enabled device owned by the authenticated user. Client employee fields are ignored. Each result has accepted/duplicate/retryable/error and server receipt time.

`event_id` is database-unique. A pre-check handles normal retry and `DuplicateEntryError` handles concurrent races. No manual commits are used. Run `bench --site SITE run-tests --app geofence_logger`.

Production requires valid TLS, credential rotation, rate limiting, audit review, backups, and role review.
