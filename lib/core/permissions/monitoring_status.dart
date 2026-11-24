import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

class MonitoringStatus {
  final bool locationServices;
  final bool foregroundPermission;
  final bool backgroundPermission;
  final bool precisePermission;
  final bool notificationsPermission;
  final bool googlePlayServicesAvailable;
  final bool ignoringBatteryOptimizations;
  final int registeredGeofenceCount;
  final String workManagerState;
  final String? nativeError;

  const MonitoringStatus({
    required this.locationServices,
    required this.foregroundPermission,
    required this.backgroundPermission,
    required this.precisePermission,
    required this.notificationsPermission,
    required this.googlePlayServicesAvailable,
    required this.ignoringBatteryOptimizations,
    required this.registeredGeofenceCount,
    required this.workManagerState,
    this.nativeError,
  });

  bool get ready =>
      locationServices &&
      foregroundPermission &&
      backgroundPermission &&
      precisePermission &&
      googlePlayServicesAvailable;
}

class MonitoringStatusService {
  static const _channel = MethodChannel(
    'com.geopulse.geofence_logger/diagnostics',
  );

  Future<MonitoringStatus> inspect({required int registeredCount}) async {
    final location = await Permission.location.status;
    final always = await Permission.locationAlways.status;
    Map<dynamic, dynamic> native = const {};
    String? error;
    try {
      native =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('status') ??
          const {};
    } catch (e) {
      error = '$e';
    }
    var precise = location.isGranted && !location.isLimited;
    try {
      precise =
          location.isGranted &&
          await geo.Geolocator.getLocationAccuracy() ==
              geo.LocationAccuracyStatus.precise;
    } catch (_) {
      // Keep the permission-handler result on platforms that cannot report
      // reduced/precise accuracy separately.
    }
    return MonitoringStatus(
      locationServices: await geo.Geolocator.isLocationServiceEnabled(),
      foregroundPermission: location.isGranted,
      backgroundPermission: always.isGranted,
      precisePermission: precise,
      notificationsPermission: await Permission.notification.isGranted,
      googlePlayServicesAvailable:
          native['googlePlayServicesAvailable'] == true,
      ignoringBatteryOptimizations:
          native['ignoringBatteryOptimizations'] == true,
      registeredGeofenceCount: registeredCount,
      workManagerState: '${native['workManagerState'] ?? 'UNKNOWN'}',
      nativeError:
          error ??
          (native['googlePlayServicesAvailable'] == true
              ? null
              : native['googlePlayServicesMessage'] as String?),
    );
  }

  Future<void> openBatteryOptimizationSettings() =>
      _channel.invokeMethod('openBatteryOptimizationSettings');
}
