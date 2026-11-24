import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'geofence_events',
            'Geofence events',
            description: 'Entry, exit, and monitoring alerts',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> event(String type, String name) => plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    type == 'ENTER' ? 'Entered $name' : 'Exited $name',
    'The event was saved on this device.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'geofence_events',
        'Geofence events',
        channelDescription: 'Entry, exit, and monitoring alerts',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
    ),
  );
}
