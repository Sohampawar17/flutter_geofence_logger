import frappe
from frappe.tests.utils import FrappeTestCase

from geofence_logger.api import ingest_events, ingest_attendance


class TestGeofenceApi(FrappeTestCase):
    def setUp(self):
        self.user = "geofence-test@example.com"
        if not frappe.db.exists("User", self.user):
            frappe.get_doc({
                "doctype": "User", "email": self.user, "first_name": "Geofence", "send_welcome_email": 0,
            }).insert(ignore_permissions=True)
        frappe.set_user(self.user)
        if not frappe.db.exists("Geofence Device Registration", {"device_id": "test-device"}):
            frappe.get_doc({
                "doctype": "Geofence Device Registration", "device_id": "test-device",
                "api_user": self.user, "enabled": 1,
            }).insert(ignore_permissions=True)

    def tearDown(self):
        frappe.set_user("Administrator")

    def payload(self):
        return {
            "event_id": "test-event-idempotent", "geofence_id": "office", "event_type": "ENTER",
            "event_timestamp": "2026-01-01T10:00:00Z", "radius_meters": 200,
            "device_id": "test-device", "latitude": 18.5, "longitude": 73.8,
        }

    def test_ingestion_is_idempotent(self):
        first = ingest_events([self.payload()])
        second = ingest_events([self.payload()])
        self.assertTrue(first["results"][0]["accepted"])
        self.assertTrue(second["results"][0]["duplicate"])

    def test_rejects_invalid_event_type(self):
        payload = self.payload()
        payload["event_id"] = "test-invalid-type"
        payload["event_type"] = "DWELL"
        result = ingest_events([payload])
        self.assertFalse(result["results"][0]["accepted"])

    def test_attendance_requires_employee_mapping(self):
        result = None
        try:
            result = ingest_attendance([{
                "attendance_id": "attendance-without-employee",
                "action": "IN", "event_timestamp": "2026-01-01T10:00:00Z",
                "latitude": 18.5, "longitude": 73.8, "accuracy_meters": 12,
                "device_id": "test-device",
            }])
        except frappe.PermissionError:
            pass
        self.assertIsNone(result)
