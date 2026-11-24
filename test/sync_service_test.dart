import 'dart:async';
import 'dart:convert';

import 'package:flutter_geofence_logger/features/event_logs/data/app_database.dart';
import 'package:flutter_geofence_logger/features/event_logs/domain/geofence_event.dart';
import 'package:flutter_geofence_logger/features/geofence/domain/geofence_config.dart';
import 'package:flutter_geofence_logger/features/synchronization/data/api_credentials_store.dart';
import 'package:flutter_geofence_logger/features/synchronization/data/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Credentials extends ApiCredentialsStore {
  @override
  Future<ApiCredentials> read() async =>
      const ApiCredentials('https://example.test', 'key', 'secret');
}

void main() {
  sqfliteFfiInit();
  late Database raw;
  late AppDatabase database;

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    database = AppDatabase.forTesting(raw);
    await database.createSchemaForTesting();
    final now = DateTime.utc(2026, 11, 24, 9);
    await database.saveGeofence(
      GeofenceConfig(
        id: 'office',
        name: 'Office',
        latitude: 18.5,
        longitude: 73.8,
        radiusMeters: 200,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.insertTransition(
      GeofenceEventRecord(
        eventId: 'event-1',
        geofenceId: 'office',
        eventType: GeofenceTransition.enter,
        eventTimestamp: now,
        radiusMeters: 200,
        deviceId: 'device-1',
        syncStatus: SyncStatus.pending,
        retryCount: 0,
        createdAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  Future<Map<String, Object?>> stored() async =>
      (await raw.query('geofence_events')).single;

  test('exact server acknowledgement marks event synced', () async {
    final client = MockClient((request) async {
      final payload = jsonDecode(request.bodyFields['events']!) as List;
      expect(payload.single, isNot(contains('sync_status')));
      expect(payload.single, isNot(contains('last_error')));
      expect(payload.single['event_id'], 'event-1');
      return http.Response(
        jsonEncode({
          'message': {
            'results': [
              {
                'event_id': 'event-1',
                'accepted': true,
                'server_received_at': '2026-11-24T09:01:00Z',
              },
            ],
          },
        }),
        200,
      );
    });

    final result = await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    expect(result.uploaded, 1);
    expect((await stored())['sync_status'], 'synced');
  });

  test('duplicate acknowledgement is treated as exact acceptance', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'message': {
            'results': [
              {'event_id': 'event-1', 'duplicate': true},
            ],
          },
        }),
        200,
      ),
    );

    await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    expect((await stored())['sync_status'], 'synced');
  });

  test('missing acknowledgement remains retryable', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'message': {'results': <Object>[]},
        }),
        200,
      ),
    );

    final result = await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    final row = await stored();
    expect(result.retryableFailure, isTrue);
    expect(row['sync_status'], 'failed');
    expect(row['last_error'], startsWith('temporary:'));
  });

  test('HTTP 429 releases event for retry', () async {
    final client = MockClient((_) async => http.Response('rate limited', 429));

    await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    final row = await stored();
    expect(row['sync_status'], 'failed');
    expect(row['last_error'], startsWith('temporary:'));
  });

  test('expired credentials remain recoverable after a later login', () async {
    final client = MockClient((_) async => http.Response('unauthorized', 401));

    await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    final row = await stored();
    expect(row['sync_status'], 'failed');
    expect(row['last_error'], startsWith('temporary:'));
  });

  test('timeout does not acknowledge or strand the event', () async {
    final client = MockClient((_) => throw TimeoutException('offline'));

    await SyncService(
      database: database,
      credentialsStore: _Credentials(),
      client: client,
    ).synchronize();

    final row = await stored();
    expect(row['sync_status'], 'failed');
    expect(row['sync_started_at'], isNull);
    expect(row['last_error'], startsWith('temporary:'));
  });
}
