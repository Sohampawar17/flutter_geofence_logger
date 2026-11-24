import 'dart:convert';

import 'package:flutter_geofence_logger/core/errors/app_exception.dart';
import 'package:flutter_geofence_logger/features/attendance/data/mobile_api_service.dart';
import 'package:flutter_geofence_logger/features/authentication/data/employee_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAuthService extends EmployeeAuthService {
  _FakeAuthService();

  @override
  Future<EmployeeSession> read() async => const EmployeeSession(
    baseUrl: 'https://sanpra.erpkey.in',
    apiKey: 'test-key',
    apiSecret: 'test-secret',
    employeeName: 'Test Employee',
    employeeId: 'HR-EMP-00001',
  );
}

void main() {
  test(
    'dashboard sends token authentication and parses Frappe wrapper',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/method/geofence_logger.mobile.app.get_dashboard',
        );
        expect(request.headers['authorization'], 'token test-key:test-secret');
        return http.Response(
          jsonEncode({
            'message': {
              'message': 'Dashboard',
              'data': {'next_log_type': 'OUT', 'button_label': 'Check Out'},
            },
          }),
          200,
        );
      });
      final service = MobileApiService(
        auth: _FakeAuthService(),
        client: client,
      );

      final result = await service.getDashboard();

      expect(result['next_log_type'], 'OUT');
      expect(result['button_label'], 'Check Out');
    },
  );

  test('attendance sends selected month and year', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['month'], '11');
      expect(request.url.queryParameters['year'], '2026');
      return http.Response(
        jsonEncode({
          'message': 'Monthly Attendance',
          'data': {
            'summary': {'total_records': 1},
            'attendance': [
              {'name': 'HR-ATT-00001', 'status': 'Present'},
            ],
          },
        }),
        200,
      );
    });
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    final result = await service.getAttendanceList(month: 11, year: 2026);

    expect((result['summary'] as Map)['total_records'], 1);
    expect((result['attendance'] as List), hasLength(1));
  });

  test('locations parse coordinates and radius from the API', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'message': 'Assigned Locations',
          'data': [
            {
              'geofence_id': 'LOC-1',
              'location_name': 'Main Office',
              'latitude': 18.5204,
              'longitude': 73.8567,
              'radius_meters': 200,
            },
          ],
        }),
        200,
      ),
    );
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    final result = await service.getLocations();

    expect(result, hasLength(1));
    expect(result.single['geofence_id'], 'LOC-1');
    expect(result.single['radius_meters'], 200);
  });

  test('employee device enrollment sends installation identity', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/method/geofence_logger.api.ensure_employee_device',
      );
      expect(request.headers['authorization'], 'token test-key:test-secret');
      expect(request.bodyFields['device_id'], 'installation-1');
      expect(request.bodyFields['device_name'], 'Test Phone');
      return http.Response(
        jsonEncode({
          'message': {
            'enrolled': true,
            'device_registration': 'REG-1',
            'employee': 'HR-EMP-00001',
          },
        }),
        200,
      );
    });
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    final result = await service.ensureEmployeeDevice(
      deviceId: 'installation-1',
      deviceName: 'Test Phone',
    );

    expect(result['enrolled'], isTrue);
    expect(result['employee'], 'HR-EMP-00001');
  });

  test('non-success server responses throw an AppException', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'message': 'Assigned locations are unavailable'}),
        417,
      ),
    );
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    expect(service.getLocations(), throwsA(isA<AppException>()));
  });

  test('invalid JSON responses throw an AppException', () async {
    final client = MockClient(
      (request) async => http.Response('not-json', 200),
    );
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    expect(service.getDashboard(), throwsA(isA<AppException>()));
  });

  test('retries once when the server closes the connection early', () async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      if (attempts == 1) {
        throw http.ClientException(
          'Connection closed before full header was received',
          request.url,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {
            'data': {'next_log_type': 'IN'},
          },
        }),
        200,
      );
    });
    final service = MobileApiService(auth: _FakeAuthService(), client: client);

    final result = await service.getDashboard();

    expect(attempts, 2);
    expect(result['next_log_type'], 'IN');
  });
}
