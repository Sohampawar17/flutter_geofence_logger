import '../../../core/utils/validators.dart';

class GeofenceConfig {
  final String id;
  final String name;
  final String? address;
  final String? assignedTo;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GeofenceConfig({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.assignedTo,
  });

  void validate() => Validators.geofence(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );

  GeofenceConfig copyWith({
    String? name,
    String? address,
    String? assignedTo,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? enabled,
    DateTime? updatedAt,
  }) => GeofenceConfig(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    assignedTo: assignedTo ?? this.assignedTo,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'geofence_id': id,
    'name': name,
    'address': address,
    'assigned_to': assignedTo,
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'enabled': enabled ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory GeofenceConfig.fromMap(Map<String, Object?> map) => GeofenceConfig(
    id: '${map['geofence_id'] ?? map['id']}',
    name: '${map['name']}',
    address: map['address'] as String?,
    assignedTo: map['assigned_to'] as String?,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    radiusMeters: (map['radius_meters'] as num).toDouble(),
    enabled: map['enabled'] == 1,
    createdAt: DateTime.parse('${map['created_at']}'),
    updatedAt:
        DateTime.tryParse('${map['updated_at']}') ??
        DateTime.parse('${map['created_at']}'),
  );
}
