import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/utils/api_logger.dart';
import '../../authentication/data/employee_auth_service.dart';

class MobileApiService {
  static const _path = '/api/method/geofence_logger.mobile.app';
  final EmployeeAuthService auth;
  final http.Client client;

  MobileApiService({EmployeeAuthService? auth, http.Client? client})
    : auth = auth ?? EmployeeAuthService(),
      client = client ?? http.Client();

  Future<Map<String, dynamic>> getDashboard() async {
    final body = await _get('get_dashboard');
    return (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<Map<String, dynamic>> getAttendanceList({
    int? month,
    int? year,
  }) async {
    final query = <String, String>{
      if (month != null) 'month': '$month',
      if (year != null) 'year': '$year',
    };
    final body = await _get('get_attendance_list', query: query);
    return (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    final body = await _get('get_locations');
    return (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> ensureEmployeeDevice({
    required String deviceId,
    required String deviceName,
  }) async {
    final session = await auth.read();
    if (!session.authenticated) {
      throw const AuthenticationException('Sign in to continue.');
    }
    final uri = Uri.parse(
      '${session.baseUrl}/api/method/geofence_logger.api.ensure_employee_device',
    );
    final timer = Stopwatch()..start();
    ApiLogger.request('POST', uri, details: 'device_id=<redacted>');
    late http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: {
              'Authorization': 'token ${session.apiKey}:${session.apiSecret}',
              'Accept': 'application/json',
            },
            body: {'device_id': deviceId, 'device_name': deviceName},
          )
          .timeout(const Duration(seconds: 20));
      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        response.body,
        timer.elapsed,
      );
    } catch (error) {
      ApiLogger.error('POST', uri, error, StackTrace.current, timer.elapsed);
      throw ApiError.connection(error, operation: 'Device enrollment');
    }
    final root = _decode(response.body);
    final body = root['message'] is Map
        ? (root['message'] as Map).cast<String, dynamic>()
        : root;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: 'Device enrollment',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _get(
    String method, {
    Map<String, String> query = const {},
  }) async {
    final session = await auth.read();
    if (!session.authenticated) {
      throw const AuthenticationException('Sign in to continue.');
    }
    final uri = Uri.parse(
      '${session.baseUrl}$_path.$method',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final timer = Stopwatch()..start();
    ApiLogger.request('GET', uri);
    late http.Response response;
    try {
      for (var attempt = 0; ; attempt++) {
        try {
          response = await client
              .get(
                uri,
                headers: {
                  'Authorization':
                      'token ${session.apiKey}:${session.apiSecret}',
                  'Accept': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 20));
          break;
        } on http.ClientException {
          if (attempt >= 1) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      ApiLogger.response(
        'GET',
        uri,
        response.statusCode,
        response.body,
        timer.elapsed,
      );
    } catch (error, stackTrace) {
      ApiLogger.error('GET', uri, error, stackTrace, timer.elapsed);
      throw ApiError.connection(error, operation: method.replaceAll('_', ' '));
    }
    final root = _decode(response.body);
    final body = root['message'] is Map
        ? (root['message'] as Map).cast<String, dynamic>()
        : root;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: method.replaceAll('_', ' '),
      );
    }
    return body;
  }

  Map<String, dynamic> _decode(String source) {
    try {
      return (jsonDecode(source) as Map).cast<String, dynamic>();
    } catch (_) {
      throw const AppException('The server returned an invalid response.');
    }
  }
}
