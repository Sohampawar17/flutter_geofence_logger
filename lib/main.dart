import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/utils/geofence_debug_log.dart';
import 'features/geofence/data/geofence_service.dart';
import 'features/geofence/data/notification_service.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GeofenceDebugLog.info('App starting; initializing native geofence manager.');
  await GeofenceService().initialize();
  GeofenceDebugLog.info('Native geofence manager initialized.');
  await NotificationService.initialize();
  GeofenceDebugLog.info('Notifications initialized; launching UI.');
  runApp(const GeoPulseApp());
}
