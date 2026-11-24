import 'package:flutter_geofence_logger/features/event_logs/domain/geofence_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geofence payload includes all diagnostics fields for ingestion', () {
    final event = GeofenceEventRecord(
      eventId: 'event-1',
      geofenceId: 'office-1',
      eventType: GeofenceTransition.enter,
      eventTimestamp: DateTime.utc(2026, 11, 24, 10, 30),
      latitude: 17.3072686,
      longitude: 74.1868507,
      accuracyMeters: 8.5,
      radiusMeters: 100,
      distanceFromCenterMeters: 24.25,
      batteryPercentage: 72,
      chargingStatus: 'discharging',
      networkType: 'mobile',
      internetAvailable: true,
      deviceId: 'device-1',
      androidVersion: '16 (SDK 36)',
      deviceManufacturer: 'Google',
      deviceModel: 'Pixel 9',
      backgroundEvent: true,
      syncStatus: SyncStatus.pending,
      retryCount: 0,
      createdAt: DateTime.utc(2026, 11, 24, 10, 30, 1),
    );

    final payload = event.toMap();

    expect(payload, containsPair('accuracy_meters', 8.5));
    expect(payload, containsPair('distance_from_center_meters', 24.25));
    expect(payload, containsPair('battery_percentage', 72));
    expect(payload, containsPair('charging_status', 'discharging'));
    expect(payload, containsPair('network_type', 'mobile'));
    expect(payload, containsPair('internet_available', 1));
    expect(payload, containsPair('android_version', '16 (SDK 36)'));
    expect(payload, containsPair('device_manufacturer', 'Google'));
    expect(payload, containsPair('device_model', 'Pixel 9'));
    expect(payload, containsPair('background_event', 1));
    expect(payload, containsPair('created_at', '2026-11-24T10:30:01.000Z'));
  });

  test('nullable diagnostics remain present for older-compatible payloads', () {
    final payload = GeofenceEventRecord(
      eventId: 'event-2',
      geofenceId: 'office-1',
      eventType: GeofenceTransition.exit,
      eventTimestamp: DateTime.utc(2026, 11, 24, 11),
      radiusMeters: 100,
      deviceId: 'device-1',
      syncStatus: SyncStatus.pending,
      retryCount: 0,
      createdAt: DateTime.utc(2026, 11, 24, 11),
    ).toMap();

    for (final field in <String>[
      'accuracy_meters',
      'distance_from_center_meters',
      'battery_percentage',
      'charging_status',
      'network_type',
      'internet_available',
      'android_version',
      'device_manufacturer',
      'device_model',
      'background_event',
      'created_at',
    ]) {
      expect(payload, contains(field));
    }
  });
}
