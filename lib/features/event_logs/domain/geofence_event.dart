enum GeofenceTransition { enter, exit }

enum SyncStatus { pending, syncing, synced, failed }

class GeofenceEventRecord {
  final String eventId;
  final String geofenceId;
  final GeofenceTransition eventType;
  final DateTime eventTimestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double radiusMeters;
  final double? distanceFromCenterMeters;
  final int? batteryPercentage;
  final String? chargingStatus;
  final String? networkType;
  final bool? internetAvailable;
  final String deviceId;
  final String? androidVersion;
  final String? deviceManufacturer;
  final String? deviceModel;
  final bool? backgroundEvent;
  final SyncStatus syncStatus;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const GeofenceEventRecord({
    required this.eventId,
    required this.geofenceId,
    required this.eventType,
    required this.eventTimestamp,
    required this.radiusMeters,
    required this.deviceId,
    required this.syncStatus,
    required this.retryCount,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.distanceFromCenterMeters,
    this.batteryPercentage,
    this.chargingStatus,
    this.networkType,
    this.internetAvailable,
    this.androidVersion,
    this.deviceManufacturer,
    this.deviceModel,
    this.backgroundEvent,
    this.lastError,
    this.syncedAt,
  });

  Map<String, Object?> toMap() => {
    'event_id': eventId,
    'geofence_id': geofenceId,
    'event_type': eventType == GeofenceTransition.enter ? 'ENTER' : 'EXIT',
    'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracyMeters,
    'radius_meters': radiusMeters,
    'distance_from_center_meters': distanceFromCenterMeters,
    'battery_percentage': batteryPercentage,
    'charging_status': chargingStatus,
    'network_type': networkType,
    'internet_available': internetAvailable == null
        ? null
        : (internetAvailable! ? 1 : 0),
    'device_id': deviceId,
    'android_version': androidVersion,
    'device_manufacturer': deviceManufacturer,
    'device_model': deviceModel,
    'background_event': backgroundEvent == null
        ? null
        : (backgroundEvent! ? 1 : 0),
    'sync_status': syncStatus.name,
    'retry_count': retryCount,
    'last_error': lastError,
    'created_at': createdAt.toUtc().toIso8601String(),
    'synced_at': syncedAt?.toUtc().toIso8601String(),
  };
}
