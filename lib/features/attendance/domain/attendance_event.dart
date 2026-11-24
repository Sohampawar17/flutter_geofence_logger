enum AttendanceAction { checkIn, checkOut }

class AttendanceEvent {
  final String id;
  final AttendanceAction action;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int? batteryPercentage;
  final String? chargingStatus;
  final String? networkType;
  final bool? internetAvailable;
  final String deviceId;
  final String employeeId;
  final String? androidVersion;
  final String? manufacturer;
  final String? model;

  const AttendanceEvent({
    required this.id,
    required this.action,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.deviceId,
    required this.employeeId,
    this.batteryPercentage,
    this.chargingStatus,
    this.networkType,
    this.internetAvailable,
    this.androidVersion,
    this.manufacturer,
    this.model,
  });

  Map<String, Object?> toMap() => {
    'attendance_id': id,
    'action': action == AttendanceAction.checkIn ? 'IN' : 'OUT',
    'event_timestamp': timestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracyMeters,
    'battery_percentage': batteryPercentage,
    'charging_status': chargingStatus,
    'network_type': networkType,
    'internet_available': internetAvailable == null
        ? null
        : (internetAvailable! ? 1 : 0),
    'device_id': deviceId,
    'employee_id': employeeId,
    'android_version': androidVersion,
    'device_manufacturer': manufacturer,
    'device_model': model,
    'sync_status': 'pending',
    'retry_count': 0,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };
}
