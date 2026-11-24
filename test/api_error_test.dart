import 'package:flutter_geofence_logger/core/errors/app_exception.dart';
import 'package:flutter_geofence_logger/core/utils/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts and strips HTML from Frappe server messages', () {
    final error = ApiError.response(
      417,
      r'''{"_server_messages":"[\"{\\\"message\\\":\\\"<b>Device</b> is already assigned\\\"}\"]"}''',
      operation: 'Device enrollment',
    );

    expect(error.message, 'Device is already assigned');
  });

  test('uses actionable message for missing API', () {
    final error = ApiError.response(404, '{}', operation: 'Device enrollment');

    expect(error.message, contains('Update the Frappe app'));
  });

  test('classifies authorization errors', () {
    final error = ApiError.response(
      403,
      '{"message":"Device belongs to another employee"}',
      operation: 'Device enrollment',
    );

    expect(error, isA<AuthenticationException>());
    expect(error.message, 'Device belongs to another employee');
  });
}
