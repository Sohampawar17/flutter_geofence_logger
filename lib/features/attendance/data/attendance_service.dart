import 'dart:convert';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/utils/api_logger.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../authentication/data/employee_auth_service.dart';
import '../../device_info/device_snapshot_service.dart';
import '../../event_logs/data/app_database.dart';
import '../domain/attendance_event.dart';

class AttendanceService {
  final AppDatabase database;
  final EmployeeAuthService auth;
  final http.Client client;

  AttendanceService({
    AppDatabase? database,
    EmployeeAuthService? auth,
    http.Client? client,
  }) : database = database ?? AppDatabase.instance,
       auth = auth ?? EmployeeAuthService(),
       client = client ?? http.Client();

  Future<void> record(AttendanceAction action) async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location before recording attendance.');
    }
    final permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      throw StateError('Precise location permission is required.');
    }
    final session = await auth.read();
    if (!session.authenticated) {
      throw StateError('Sign in before recording attendance.');
    }
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.accuracy > 100) {
      throw StateError(
        'Location accuracy is too low (${position.accuracy.round()} m). Move outdoors and retry.',
      );
    }
    final device = await DeviceSnapshotService().capture();
    await database.insertAttendance(
      AttendanceEvent(
        id: const Uuid().v4(),
        action: action,
        timestamp: DateTime.now().toUtc(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        batteryPercentage: device.batteryPercentage,
        chargingStatus: device.chargingStatus,
        networkType: device.networkType,
        internetAvailable: device.internetAvailable,
        deviceId: device.deviceId,
        employeeId: session.employeeId,
        androidVersion: device.androidVersion,
        manufacturer: device.manufacturer,
        model: device.model,
      ),
    );
  }

  Future<void> synchronize() async {
    final session = await auth.read();
    if (!session.authenticated) return;
    final batch = await database.claimAttendanceBatch(session.employeeId);
    if (batch.isEmpty) return;
    String? failureMessage;
    try {
      final uri = Uri.parse(
        '${session.baseUrl}/api/method/geofence_logger.api.ingest_attendance',
      );
      final timer = Stopwatch()..start();
      ApiLogger.request(
        'POST',
        uri,
        details: 'events=${batch.length}; identifiers=<redacted>',
      );
      final response = await client
          .post(
            uri,
            headers: {
              'Authorization': 'token ${session.apiKey}:${session.apiSecret}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'events': batch}),
          )
          .timeout(const Duration(seconds: 30));
      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        response.body,
        timer.elapsed,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final apiError = ApiError.response(
          response.statusCode,
          response.body,
          operation: 'Attendance synchronization',
        );
        throw apiError;
      }
      final root = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      final body = root['message'] is Map
          ? (root['message'] as Map).cast<String, dynamic>()
          : root;
      final results = (body['results'] as List? ?? const []).whereType<Map>();
      final acknowledged = <String>{};
      for (final raw in results) {
        final result = raw.cast<String, dynamic>();
        final id = '${result['attendance_id'] ?? ''}';
        if (id.isEmpty) continue;
        acknowledged.add(id);
        final accepted =
            result['accepted'] == true || result['duplicate'] == true;
        await database.completeAttendanceSync(
          id,
          accepted: accepted,
          retryable: result['retryable'] == true,
          error: accepted
              ? null
              : '${result['error'] ?? 'Server rejected attendance'}',
          serverName: result['name'] as String?,
        );
        if (!accepted) {
          failureMessage ??=
              '${result['error'] ?? 'Server rejected attendance'}';
        }
      }
      for (final event in batch) {
        final id = '${event['attendance_id']}';
        if (!acknowledged.contains(id)) {
          await database.completeAttendanceSync(
            id,
            accepted: false,
            retryable: true,
            error: 'Missing server acknowledgement',
          );
          failureMessage ??=
              'The server did not acknowledge every attendance record.';
        }
      }
      if (failureMessage != null) throw AppException(failureMessage);
    } catch (error) {
      await database.releaseAttendanceBatch(
        '$error',
        attendanceIds: batch.map((event) => '${event['attendance_id']}'),
      );
      rethrow;
    }
  }
}
