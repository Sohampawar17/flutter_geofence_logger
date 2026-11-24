import 'package:flutter/services.dart';

import '../../core/utils/geofence_debug_log.dart';

class BackgroundSyncScheduler {
  static const _channel = MethodChannel(
    'com.geopulse.geofence_logger/background',
  );

  Future<void> initialize() async {
    GeofenceDebugLog.info('Initializing native background event sync.');
    await _channel.invokeMethod('initializeSync');
    GeofenceDebugLog.info('Native background event sync initialized.');
  }

  Future<void> enqueue() async {
    GeofenceDebugLog.info('Requesting a background event sync run.');
    await _channel.invokeMethod('enqueueSync');
    GeofenceDebugLog.info('Background event sync request queued.');
  }
}
