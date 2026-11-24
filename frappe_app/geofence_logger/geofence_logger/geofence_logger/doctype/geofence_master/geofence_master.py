from frappe.model.document import Document


class GeofenceMaster(Document):
    def validate(self):
        if not -90 <= self.latitude <= 90 or not -180 <= self.longitude <= 180:
            raise ValueError("Invalid geofence coordinates")
        if not 1 <= self.radius_meters <= 100000:
            raise ValueError("Invalid radius")
