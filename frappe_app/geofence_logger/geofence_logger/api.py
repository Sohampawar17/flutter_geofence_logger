import json
from datetime import datetime, timezone

import frappe
from frappe import _
from frappe.exceptions import DuplicateEntryError
from frappe.utils import cint, flt, get_datetime, getdate

ALLOWED_EVENT_TYPES = {"ENTER", "EXIT"}
ALLOWED_ATTENDANCE_ACTIONS = {"IN", "OUT"}
ALLOWED_SYNC_FIELDS = {
    "event_id", "geofence_id", "event_type", "event_timestamp", "latitude", "longitude",
    "accuracy_meters", "radius_meters", "distance_from_center_meters", "battery_percentage",
    "charging_status", "network_type", "internet_available", "device_id", "android_version",
    "device_manufacturer", "device_model", "background_event", "created_at",
}


def _require_authenticated_user():
    if frappe.session.user == "Guest":
        frappe.throw(_("Authentication required"), frappe.AuthenticationError)


def _employee_for_user():
    _require_authenticated_user()
    employee = frappe.db.get_value("Employee", {
        "user_id": frappe.session.user, "status": "Active",
    }, ["name", "employee_name"], as_dict=True)
    if not employee:
        frappe.throw(_("Your account is not linked to an active Employee"), frappe.PermissionError)
    return employee


def _attendance_review_reason(employee, action, timestamp):
    """Return why a raw event must not alter standard attendance."""
    if frappe.db.exists("Attendance", {
        "employee": employee, "attendance_date": getdate(timestamp), "docstatus": 1,
    }):
        return "Attendance for this date is already finalized"
    if not frappe.db.exists("DocType", "Employee Checkin"):
        return "Employee Checkin is unavailable"
    if frappe.db.exists("Employee Checkin", {
        "employee": employee, "time": (">", timestamp),
    }):
        return "A later check-in already exists; event arrived out of order"
    previous = frappe.db.get_value(
        "Employee Checkin",
        {"employee": employee, "time": ("<=", timestamp)},
        ["log_type", "time"],
        as_dict=True,
        order_by="time desc",
    )
    if action == "OUT" and (not previous or previous.log_type != "IN"):
        return "Check Out has no preceding Check In"
    if action == "IN" and previous and previous.log_type == "IN":
        return "Consecutive Check In requires review"
    return None


@frappe.whitelist(methods=["GET"])
def employee_profile():
    employee = _employee_for_user()
    return {"employee": employee.name, "employee_name": employee.employee_name,
            "user": frappe.session.user}


@frappe.whitelist(methods=["POST"])
def ingest_attendance(events=None):
    """Idempotently store employee IN/OUT actions with server-owned identity."""
    employee = _employee_for_user()
    if events is None:
        events = (frappe.request.get_json(silent=True) or {}).get("events")
    if isinstance(events, str):
        events = json.loads(events)
    if not isinstance(events, list) or not 1 <= len(events) <= 100:
        frappe.throw(_("events must contain 1 to 100 records"))
    results = []
    received_at = frappe.utils.now_datetime()
    for raw in events:
        attendance_id = str(raw.get("attendance_id") or "") if isinstance(raw, dict) else ""
        try:
            if not isinstance(raw, dict) or not attendance_id or len(attendance_id) > 100:
                frappe.throw(_("Invalid attendance ID"))
            action = str(raw.get("action") or "")
            if action not in ALLOWED_ATTENDANCE_ACTIONS:
                frappe.throw(_("action must be IN or OUT"))
            timestamp = get_datetime(raw.get("event_timestamp"))
            latitude = _number(raw.get("latitude"), "latitude", -90, 90, False)
            longitude = _number(raw.get("longitude"), "longitude", -180, 180, False)
            accuracy = _number(raw.get("accuracy_meters"), "accuracy_meters", 0, 100, False)
            existing = frappe.db.exists("GeoPulse Attendance Log", {"attendance_id": attendance_id})
            if existing:
                results.append({"attendance_id": attendance_id, "accepted": True,
                                "duplicate": True, "name": existing})
                continue
            battery = raw.get("battery_percentage")
            if battery is not None:
                battery = int(_number(battery, "battery_percentage", 0, 100, False))
            doc = frappe.get_doc({
                "doctype": "GeoPulse Attendance Log", "attendance_id": attendance_id,
                "employee": employee.name, "api_user": frappe.session.user,
                "action": action, "event_timestamp": timestamp,
                "server_received_at": received_at, "latitude": latitude,
                "longitude": longitude, "accuracy_meters": accuracy,
                "battery_percentage": battery,
                "charging_status": str(raw.get("charging_status") or "")[:80],
                "network_type": str(raw.get("network_type") or "")[:140],
                "internet_available": cint(raw.get("internet_available")),
                "device_id": str(raw.get("device_id") or "")[:100],
                "android_version": str(raw.get("android_version") or "")[:140],
                "device_manufacturer": str(raw.get("device_manufacturer") or "")[:140],
                "device_model": str(raw.get("device_model") or "")[:140],
                "processing_status": "Raw",
            })
            doc.insert(ignore_permissions=True)
            review_reason = _attendance_review_reason(employee.name, action, timestamp)
            if review_reason:
                doc.processing_status = "Review"
                doc.review_reason = review_reason
            else:
                try:
                    checkin = frappe.get_doc({
                        "doctype": "Employee Checkin", "employee": employee.name,
                        "time": timestamp, "log_type": action,
                        "device_id": str(raw.get("device_id") or "")[:100],
                        "latitude": latitude, "longitude": longitude,
                    }).insert(ignore_permissions=True)
                    doc.processing_status = "Applied"
                    doc.standard_checkin = checkin.name
                except Exception:
                    frappe.log_error(frappe.get_traceback(), "Attendance application review")
                    doc.processing_status = "Review"
                    doc.review_reason = "ERPNext rejected automatic check-in creation"
            doc.save(ignore_permissions=True)
            results.append({"attendance_id": attendance_id, "accepted": True,
                            "duplicate": False, "name": doc.name,
                            "processing_status": doc.processing_status,
                            "review_reason": doc.review_reason})
        except DuplicateEntryError:
            results.append({"attendance_id": attendance_id, "accepted": True, "duplicate": True})
        except (frappe.ValidationError, frappe.PermissionError) as exc:
            results.append({"attendance_id": attendance_id, "accepted": False,
                            "retryable": False, "error": str(exc)[:300]})
        except Exception:
            frappe.log_error(frappe.get_traceback(), "Attendance ingestion")
            results.append({"attendance_id": attendance_id, "accepted": False,
                            "retryable": True, "error": "Temporary server failure"})
    return {"ok": all(row.get("accepted") for row in results), "results": results}


def _manager_only():
    _require_authenticated_user()
    roles = set(frappe.get_roles(frappe.session.user))
    if not roles.intersection({"System Manager", "Geofence Manager"}):
        frappe.throw(_("Geofence Manager role required"), frappe.PermissionError)


@frappe.whitelist(methods=["POST"])
def enroll_device(device_id: str, device_name: str | None = None, employee: str | None = None):
    """Admin-controlled enrollment. Employee mapping is never trusted from event payloads."""
    _manager_only()
    device_id = (device_id or "").strip()
    if not device_id or len(device_id) > 100:
        frappe.throw(_("Invalid device ID"))
    existing = frappe.db.exists("Geofence Device Registration", {"device_id": device_id})
    doc = frappe.get_doc("Geofence Device Registration", existing) if existing else frappe.new_doc("Geofence Device Registration")
    doc.device_id = device_id
    doc.device_name = (device_name or "")[:140]
    doc.api_user = frappe.session.user
    doc.employee = employee if employee and frappe.db.exists("Employee", employee) else None
    doc.enabled = 1
    doc.last_enrolled_at = frappe.utils.now_datetime()
    doc.save(ignore_permissions=True)
    return {"ok": True, "device_registration": doc.name, "server_received_at": frappe.utils.now()}


@frappe.whitelist(methods=["POST"])
def ensure_employee_device(device_id: str, device_name: str | None = None):
    """Idempotently bind an installation to the authenticated employee."""
    employee = _employee_for_user()
    device_id = (device_id or "").strip()
    if not device_id or len(device_id) > 100:
        frappe.throw(_("Invalid device ID"))

    existing = frappe.db.exists("Geofence Device Registration", {"device_id": device_id})
    if existing:
        doc = frappe.get_doc("Geofence Device Registration", existing)
        if doc.employee and doc.employee != employee.name:
            frappe.throw(
                _("This device is registered to another employee. Contact an administrator."),
                frappe.PermissionError,
            )
    else:
        doc = frappe.new_doc("Geofence Device Registration")
        doc.device_id = device_id

    doc.device_name = (device_name or "")[:140]
    doc.api_user = frappe.session.user
    doc.employee = employee.name
    doc.enabled = 1
    doc.last_enrolled_at = frappe.utils.now_datetime()
    doc.save(ignore_permissions=True)
    return {
        "ok": True,
        "enrolled": True,
        "device_registration": doc.name,
        "device_id": doc.device_id,
        "device_name": doc.device_name,
        "employee": doc.employee,
        "enabled": bool(doc.enabled),
        "last_enrolled_at": str(doc.last_enrolled_at),
    }


def _authorized_registration(device_id: str):
    name = frappe.db.exists("Geofence Device Registration", {
        "device_id": device_id, "api_user": frappe.session.user, "enabled": 1,
    })
    if not name:
        frappe.throw(_("Device is not enrolled for this API user"), frappe.PermissionError)
    return frappe.get_cached_doc("Geofence Device Registration", name)


def _number(value, field, minimum=None, maximum=None, nullable=True):
    if value is None and nullable:
        return None
    try:
        result = float(value)
    except (TypeError, ValueError):
        frappe.throw(_("{0} must be numeric").format(field))
    if minimum is not None and result < minimum or maximum is not None and result > maximum:
        frappe.throw(_("{0} is outside the allowed range").format(field))
    return result


def _validate_event(raw):
    if not isinstance(raw, dict):
        frappe.throw(_("Each event must be an object"))
    event = {key: raw.get(key) for key in ALLOWED_SYNC_FIELDS}
    for field in ("event_id", "geofence_id", "event_type", "event_timestamp", "device_id"):
        if not str(event.get(field) or "").strip():
            frappe.throw(_("Missing {0}").format(field))
    if event["event_type"] not in ALLOWED_EVENT_TYPES:
        frappe.throw(_("event_type must be ENTER or EXIT"))
    if len(event["event_id"]) > 100 or len(event["device_id"]) > 100:
        frappe.throw(_("Identifier is too long"))
    event["event_timestamp"] = get_datetime(event["event_timestamp"])
    event["latitude"] = _number(event.get("latitude"), "latitude", -90, 90)
    event["longitude"] = _number(event.get("longitude"), "longitude", -180, 180)
    event["accuracy_meters"] = _number(event.get("accuracy_meters"), "accuracy_meters", 0)
    event["radius_meters"] = _number(event.get("radius_meters"), "radius_meters", 1, 100000, False)
    event["distance_from_center_meters"] = _number(event.get("distance_from_center_meters"), "distance", 0)
    if event.get("battery_percentage") is not None:
        event["battery_percentage"] = int(_number(event["battery_percentage"], "battery", 0, 100, False))
    return event


@frappe.whitelist(methods=["POST"])
def ingest_events(events=None):
    """Batch, idempotent ingestion with per-item acknowledgements."""
    _require_authenticated_user()
    if events is None:
        body = frappe.request.get_json(silent=True) or {}
        events = body.get("events")
    if isinstance(events, str):
        events = json.loads(events)
    if not isinstance(events, list) or not 1 <= len(events) <= 100:
        frappe.throw(_("events must contain 1 to 100 records"))

    results = []
    received_at = frappe.utils.now_datetime()
    for raw in events:
        event_id = str(raw.get("event_id") or "") if isinstance(raw, dict) else ""
        try:
            event = _validate_event(raw)
            registration = _authorized_registration(event["device_id"])
            existing = frappe.db.exists("Geofence Event Log", {"event_id": event["event_id"]})
            if existing:
                results.append({"event_id": event["event_id"], "accepted": True, "duplicate": True,
                                "server_received_at": str(received_at)})
                continue
            master = frappe.db.exists("Geofence Master", {"external_id": event["geofence_id"], "enabled": 1})
            doc = frappe.new_doc("Geofence Event Log")
            doc.update({
                **event, "geofence_master": master, "device_registration": registration.name,
                "employee": registration.employee, "api_user": frappe.session.user,
                "server_received_at": received_at,
            })
            doc.insert(ignore_permissions=True)
            results.append({"event_id": event["event_id"], "accepted": True, "duplicate": False,
                            "server_received_at": str(received_at), "name": doc.name})
        except DuplicateEntryError:
            results.append({"event_id": event_id, "accepted": True, "duplicate": True,
                            "server_received_at": str(received_at)})
        except (frappe.ValidationError, frappe.PermissionError) as exc:
            results.append({"event_id": event_id, "accepted": False, "retryable": False, "error": str(exc)[:300]})
        except Exception:
            frappe.log_error(frappe.get_traceback(), "Geofence event ingestion")
            results.append({"event_id": event_id, "accepted": False, "retryable": True,
                            "error": "Temporary server failure"})
    return {"ok": all(row.get("accepted") for row in results), "results": results,
            "server_received_at": str(received_at)}
