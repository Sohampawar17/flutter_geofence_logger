import 'dart:math' as math;

import 'geofence_config.dart';

class GeofenceLocationEvaluation {
  final double distanceMeters;
  final bool isInside;

  const GeofenceLocationEvaluation({
    required this.distanceMeters,
    required this.isInside,
  });
}

class GeofenceLocationEvaluator {
  static const double _earthRadiusMeters = 6371008.8;

  static GeofenceLocationEvaluation evaluate({
    required GeofenceConfig geofence,
    required double latitude,
    required double longitude,
  }) {
    final distance = distanceBetween(
      geofence.latitude,
      geofence.longitude,
      latitude,
      longitude,
    );
    return GeofenceLocationEvaluation(
      distanceMeters: distance,
      isInside: distance <= geofence.radiusMeters,
    );
  }

  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final latitudeDelta = _radians(endLatitude - startLatitude);
    final longitudeDelta = _radians(endLongitude - startLongitude);
    final startLatitudeRadians = _radians(startLatitude);
    final endLatitudeRadians = _radians(endLatitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
