import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

class Validators {
  static void geofence({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    if (id.trim().isEmpty) {
      throw const ValidationException('Missing geofence ID.');
    }
    if (name.trim().isEmpty) {
      throw const ValidationException('Enter a location name.');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw const ValidationException('Latitude must be between -90 and 90.');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const ValidationException(
        'Longitude must be between -180 and 180.',
      );
    }
    if (!radiusMeters.isFinite ||
        radiusMeters < AppConstants.minRadiusMeters ||
        radiusMeters > AppConstants.maxRadiusMeters) {
      throw ValidationException(
        'Radius must be ${AppConstants.minRadiusMeters.round()}–'
        '${AppConstants.maxRadiusMeters.round()} meters.',
      );
    }
  }

  static String httpsBaseUrl(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ValidationException('A valid HTTPS Frappe URL is required.');
    }
    return normalized;
  }
}
