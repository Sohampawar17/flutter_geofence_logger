# Validation Matrix

| Rule | Source | Behavior | Test |
|---|---|---|---|
| Latitude -90…90; longitude -180…180 | validator, SQLite CHECK, Frappe | reject before registration/insert | `validation_test.dart` |
| Radius 50…10,000 client; default 200 | validator/schema | reject unsupported radius | validation test |
| Nonempty name/ID; unique IDs | model/primary keys | reject/UUID | validation test |
| ENTER/EXIT only | callback/schema/API | reject other values | Frappe test |
| UTC timestamp and unique event UUID | callback/schema/API | duplicate-safe retry | policy/API tests |
| Battery null or 0–100; accuracy null/nonnegative | snapshot/schema/API | unavailable stays null | schema/code |
| HTTPS and encrypted credentials | validator/secure storage | reject HTTP; redact logs | validation test |
| Authorized enabled device | Frappe registration | reject mismatched API user | Frappe test |
| Employee mapping | server registration only | ignore client employee identity | API code/test |
| Native registration | query after create | fail/rollback if unconfirmed | device/plugin test |
| Per-item sync acknowledgement | SyncService | missing acknowledgement remains failed | integration test |

Writes and claims are transactional. Unsynchronized events are never retention-deleted.
