import 'package:flutter_geofence_logger/features/attendance/domain/attendance_event.dart';
import 'package:flutter_geofence_logger/features/event_logs/data/app_database.dart';
import 'package:flutter_geofence_logger/features/event_logs/domain/geofence_event.dart';
import 'package:flutter_geofence_logger/features/geofence/domain/geofence_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database raw;
  late AppDatabase database;

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    database = AppDatabase.forTesting(raw);
    await database.createSchemaForTesting();
    final now = DateTime.utc(2026, 11, 24);
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
  });

  tearDown(() => database.close());

  GeofenceEventRecord event(String id, DateTime at) => GeofenceEventRecord(
    eventId: id,
    geofenceId: 'office',
    eventType: GeofenceTransition.enter,
    eventTimestamp: at,
    radiusMeters: 200,
    deviceId: 'device-1',
    syncStatus: SyncStatus.pending,
    retryCount: 0,
    createdAt: at,
  );

  GeofenceEventRecord transition(
    String id,
    DateTime at,
    GeofenceTransition type,
  ) => GeofenceEventRecord(
    eventId: id,
    geofenceId: 'office',
    eventType: type,
    eventTimestamp: at,
    radiusMeters: 200,
    deviceId: 'device-1',
    syncStatus: SyncStatus.pending,
    retryCount: 0,
    createdAt: at,
  );

  test(
    'persists state and rejects consecutive duplicate transitions',
    () async {
      final start = DateTime.utc(2026, 11, 24, 9);

      expect(
        (await database.insertTransition(
          transition('enter-1', start, GeofenceTransition.enter),
        )).inserted,
        isTrue,
      );
      final duplicateEnter = await database.insertTransition(
        transition(
          'enter-2',
          start.add(const Duration(minutes: 1)),
          GeofenceTransition.enter,
        ),
      );
      expect(duplicateEnter.inserted, isFalse);
      expect(duplicateEnter.reason, 'duplicate_state');

      expect(
        (await database.insertTransition(
          transition(
            'exit-1',
            start.add(const Duration(minutes: 2)),
            GeofenceTransition.exit,
          ),
        )).inserted,
        isTrue,
      );
      final duplicateExit = await database.insertTransition(
        transition(
          'exit-2',
          start.add(const Duration(minutes: 3)),
          GeofenceTransition.exit,
        ),
      );
      expect(duplicateExit.inserted, isFalse);
      expect(duplicateExit.reason, 'duplicate_state');

      final rows = await raw.query('geofence_events');
      expect(rows.map((row) => row['event_id']), ['enter-1', 'exit-1']);
    },
  );

  test(
    'initial EXIT establishes outside state without a false event',
    () async {
      final start = DateTime.utc(2026, 11, 24, 9);

      final initialExit = await database.insertTransition(
        transition('exit-1', start, GeofenceTransition.exit),
      );
      expect(initialExit.inserted, isFalse);
      expect(initialExit.reason, 'initial_outside_state');

      final enter = await database.insertTransition(
        transition(
          'enter-1',
          start.add(const Duration(minutes: 1)),
          GeofenceTransition.enter,
        ),
      );
      expect(enter.inserted, isTrue);

      final rows = await raw.query('geofence_events');
      expect(rows.single['event_id'], 'enter-1');
    },
  );

  test(
    'active sync lease is not reclaimed merely because event is old',
    () async {
      final old = DateTime.utc(2026, 1, 1);
      expect(
        (await database.insertTransition(event('event-1', old))).inserted,
        isTrue,
      );

      expect(await database.claimSyncBatch(), hasLength(1));
      expect(await database.claimSyncBatch(), isEmpty);
    },
  );

  test('abandoned sync lease is recovered after timeout', () async {
    final old = DateTime.utc(2026, 1, 1);
    await database.insertTransition(event('event-1', old));
    await database.claimSyncBatch();
    await raw.update('geofence_events', {
      'sync_started_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String(),
    });

    final recovered = await database.claimSyncBatch();

    expect(recovered.single['event_id'], 'event-1');
  });

  test(
    'retention deletes acknowledged events but never pending events',
    () async {
      final old = DateTime.utc(2026, 1, 1);
      await database.insertTransition(event('event-1', old));
      await database.markSynced('event-1', old);
      await raw.insert('geofence_events', {
        ...event('event-2', old.add(const Duration(minutes: 1))).toMap(),
        'event_type': 'EXIT',
      });

      expect(await database.pruneSyncedBefore(DateTime.utc(2026, 2, 1)), 1);
      final rows = await raw.query('geofence_events');
      expect(rows.single['event_id'], 'event-2');
      expect(rows.single['sync_status'], 'pending');
    },
  );

  test('attendance rejects OUT before IN and consecutive IN', () async {
    AttendanceEvent attendance(String id, AttendanceAction action) =>
        AttendanceEvent(
          id: id,
          action: action,
          timestamp: DateTime.utc(2026, 11, 24, 9),
          latitude: 18.5,
          longitude: 73.8,
          accuracyMeters: 10,
          deviceId: 'device-1',
          employeeId: 'EMP-1',
        );

    await expectLater(
      database.insertAttendance(
        attendance('out-first', AttendanceAction.checkOut),
      ),
      throwsStateError,
    );
    await database.insertAttendance(attendance('in', AttendanceAction.checkIn));
    await expectLater(
      database.insertAttendance(
        attendance('in-again', AttendanceAction.checkIn),
      ),
      throwsStateError,
    );
    await database.insertAttendance(
      attendance('out', AttendanceAction.checkOut),
    );
  });
}
