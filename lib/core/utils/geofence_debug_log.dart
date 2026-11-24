import 'dart:developer' as developer;

/// Diagnostics that remain visible when code runs in a background isolate.
class GeofenceDebugLog {
  static const String _name = 'GeoPulse-Geofence';

  static void info(String message) {
    developer.log(message, name: _name);
  }

  static void error(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: _name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
