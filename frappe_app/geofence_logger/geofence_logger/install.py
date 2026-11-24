import frappe


def after_install():
    """Create roles used by endpoint permission checks."""
    for role in ("Geofence Manager", "Geofence Device"):
        if not frappe.db.exists("Role", role):
            frappe.get_doc({"doctype": "Role", "role_name": role}).insert(ignore_permissions=True)
