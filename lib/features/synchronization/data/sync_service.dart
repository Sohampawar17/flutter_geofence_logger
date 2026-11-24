import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/api_error.dart';
import '../../event_logs/data/app_database.dart';
import 'api_credentials_store.dart';

class SyncSummary {
  final int uploaded;
  final int failed;
  final bool retryableFailure;
  final String? message;
  const SyncSummary({
    required this.uploaded,
    required this.failed,
    this.retryableFailure = false,
    this.message,
  });
}

class SyncService {
  final AppDatabase database;
  final ApiCredentialsStore credentialsStore;
  final http.Client client;

  SyncService({
    AppDatabase? database,
    ApiCredentialsStore? credentialsStore,
    http.Client? client,
  }) : database = database ?? AppDatabase.instance,
       credentialsStore = credentialsStore ?? ApiCredentialsStore(),
       client = client ?? http.Client();

  Future<SyncSummary> synchronize() async {
    final credentials = await credentialsStore.read();
    if (!credentials.configured) {
      return const SyncSummary(
        uploaded: 0,
        failed: 0,
        message: 'API is not configured.',
      );
    }
    final base = Validators.httpsBaseUrl(credentials.baseUrl);
    final batch = await database.claimSyncBatch();
    if (batch.isEmpty) {
      return const SyncSummary(
        uploaded: 0,
        failed: 0,
        message: 'Everything is synchronized.',
      );
    }
    try {
      final response = await client
          .post(
            Uri.parse('$base/api/method/geofence_logger.api.ingest_events'),
            headers: {
              'Authorization':
                  'token ${credentials.apiKey}:${credentials.apiSecret}',
              'Accept': 'application/json',
            },
            body: {'events': jsonEncode(batch.map(_apiEvent).toList())},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiError.response(
          response.statusCode,
          response.body,
          operation: 'Event synchronization',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiError.response(
          response.statusCode,
          response.body,
          operation: 'Event synchronization',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final body =
          (decoded['message'] as Map?)?.cast<String, dynamic>() ?? decoded;
      final results = (body['results'] as List? ?? const []).cast<Map>();
      var uploaded = 0;
      var failed = 0;
      final acknowledged = <String>{};
      for (final raw in results) {
        final result = raw.cast<String, dynamic>();
        final id = '${result['event_id']}';
        acknowledged.add(id);
        if (result['accepted'] == true || result['duplicate'] == true) {
          await database.markSynced(
            id,
            DateTime.tryParse('${result['server_received_at']}') ??
                DateTime.now().toUtc(),
          );
          uploaded++;
        } else {
          await database.markSyncFailed(
            id,
            '${result['error'] ?? 'Server did not acknowledge event'}',
            retryable: result['retryable'] == true,
          );
          failed++;
        }
      }
      for (final event in batch) {
        final id = '${event['event_id']}';
        if (!acknowledged.contains(id)) {
          await database.markSyncFailed(
            id,
            'Missing server acknowledgement',
            retryable: true,
          );
          failed++;
        }
      }
      return SyncSummary(
        uploaded: uploaded,
        failed: failed,
        retryableFailure: failed > 0,
      );
    } on AuthenticationException catch (error) {
      for (final event in batch) {
        await database.markSyncFailed(
          '${event['event_id']}',
          error.message,
          // A later login can replace expired credentials and explicitly
          // enqueue synchronization again.
          retryable: true,
        );
      }
      return SyncSummary(
        uploaded: 0,
        failed: batch.length,
        message: error.message,
      );
    } catch (error) {
      final failure = ApiError.connection(
        error,
        operation: 'Event synchronization',
      );
      await database.releaseSyncBatch(
        failure.message,
        eventIds: batch.map((event) => '${event['event_id']}'),
      );
      return SyncSummary(
        uploaded: 0,
        failed: batch.length,
        retryableFailure: true,
        message: failure.message,
      );
    }
  }

  Map<String, Object?> _apiEvent(Map<String, Object?> row) => {
    for (final field in const <String>[
      'event_id',
      'geofence_id',
      'event_type',
      'event_timestamp',
      'latitude',
      'longitude',
      'accuracy_meters',
      'radius_meters',
      'distance_from_center_meters',
      'battery_percentage',
      'charging_status',
      'network_type',
      'internet_available',
      'device_id',
      'android_version',
      'device_manufacturer',
      'device_model',
      'background_event',
      'created_at',
    ])
      field: row[field],
  };

  Future<String> enrollDevice({
    required String deviceId,
    String? deviceName,
  }) async {
    final credentials = await credentialsStore.read();
    if (!credentials.configured) {
      throw const AuthenticationException(
        'Configure Frappe credentials first.',
      );
    }
    final base = Validators.httpsBaseUrl(credentials.baseUrl);
    final response = await client
        .post(
          Uri.parse('$base/api/method/geofence_logger.api.enroll_device'),
          headers: {
            'Authorization':
                'token ${credentials.apiKey}:${credentials.apiSecret}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'device_id': deviceId, 'device_name': deviceName}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: 'Device enrollment',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: 'Device enrollment',
      );
    }
    return 'Device enrollment accepted.';
  }
}
