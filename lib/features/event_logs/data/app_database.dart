import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../geofence/domain/geofence_config.dart';
import '../../attendance/domain/attendance_event.dart';
import '../domain/geofence_event.dart';
import '../domain/transition_policy.dart';

class TransitionResult {
  final bool inserted;
  final String reason;
  const TransitionResult(this.inserted, this.reason);
}

class AppDatabase {
  AppDatabase._();
  AppDatabase.forTesting(Database database) : _database = database;
  static final instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async => openDatabase(
    path.join(await getDatabasesPath(), AppConstants.databaseName),
    version: AppConstants.databaseVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
      // These PRAGMAs return a result row, so Android requires the query API.
      await db.rawQuery('PRAGMA busy_timeout = 5000');
      await db.rawQuery('PRAGMA journal_mode = WAL');
    },
    onCreate: (db, _) => _createSchema(db),
    onUpgrade: _migrate,
  );

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS geofences (
      geofence_id TEXT PRIMARY KEY,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      address TEXT, assigned_to TEXT,
      latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),
      longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),
      radius_meters REAL NOT NULL CHECK(radius_meters BETWEEN 50 AND 10000),
      enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS geofence_events (
      event_id TEXT PRIMARY KEY,
      geofence_id TEXT NOT NULL,
      event_type TEXT NOT NULL CHECK(event_type IN ('ENTER','EXIT')),
      event_timestamp TEXT NOT NULL,
      latitude REAL, longitude REAL, accuracy_meters REAL CHECK(accuracy_meters IS NULL OR accuracy_meters >= 0),
      radius_meters REAL NOT NULL,
      distance_from_center_meters REAL,
      battery_percentage INTEGER CHECK(battery_percentage IS NULL OR battery_percentage BETWEEN 0 AND 100),
      charging_status TEXT, network_type TEXT,
      internet_available INTEGER CHECK(internet_available IS NULL OR internet_available IN (0,1)),
      device_id TEXT NOT NULL, android_version TEXT,
      device_manufacturer TEXT, device_model TEXT,
      background_event INTEGER CHECK(background_event IS NULL OR background_event IN (0,1)),
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK(sync_status IN ('pending','syncing','synced','failed')),
      retry_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT, created_at TEXT NOT NULL, synced_at TEXT,
      sync_started_at TEXT,
      FOREIGN KEY(geofence_id) REFERENCES geofences(geofence_id) ON DELETE RESTRICT
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS geofence_state (
      geofence_id TEXT PRIMARY KEY,
      state TEXT NOT NULL CHECK(state IN ('UNKNOWN','INSIDE','OUTSIDE')),
      last_event_at TEXT, last_callback_at TEXT NOT NULL,
      FOREIGN KEY(geofence_id) REFERENCES geofences(geofence_id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS device_registration (
      device_id TEXT PRIMARY KEY, enrollment_status TEXT NOT NULL DEFAULT 'unenrolled',
      server_device_id TEXT, last_enrolled_at TEXT, updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS diagnostics (
      diagnostic_id INTEGER PRIMARY KEY AUTOINCREMENT,
      level TEXT NOT NULL, category TEXT NOT NULL, message TEXT NOT NULL,
      details TEXT, created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS attendance_events (
      attendance_id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      action TEXT NOT NULL CHECK(action IN ('IN','OUT')),
      event_timestamp TEXT NOT NULL,
      latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),
      longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),
      accuracy_meters REAL NOT NULL CHECK(accuracy_meters >= 0),
      battery_percentage INTEGER CHECK(battery_percentage IS NULL OR battery_percentage BETWEEN 0 AND 100),
      charging_status TEXT, network_type TEXT,
      internet_available INTEGER CHECK(internet_available IS NULL OR internet_available IN (0,1)),
      device_id TEXT NOT NULL, android_version TEXT,
      device_manufacturer TEXT, device_model TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK(sync_status IN ('pending','syncing','synced','failed')),
      retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT,
      created_at TEXT NOT NULL, synced_at TEXT, server_name TEXT,
      sync_started_at TEXT
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_sync ON geofence_events(sync_status,event_timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_geofence_time ON geofence_events(geofence_id,event_timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diagnostics_time ON diagnostics(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_sync ON attendance_events(sync_status,event_timestamp)',
    );
  }

  /// Creates the production schema on an injected in-memory database.
  /// Intended for focused storage and crash-recovery tests only.
  Future<void> createSchemaForTesting() async => _createSchema(await database);

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      if (oldVersion < 6) {
        await _createSchema(txn);
        if (oldVersion == 5 &&
            await _columnExists(txn, 'attendance_events', 'employee_id') ==
                false) {
          await txn.execute(
            'ALTER TABLE attendance_events ADD COLUMN employee_id TEXT',
          );
          await txn.update('attendance_events', {'employee_id': 'legacy'});
        }
      }
      if (oldVersion < 4) {
        final oldLocations = await _tableExists(txn, 'locations');
        if (oldLocations) {
          final hasAssignedTo = await _columnExists(
            txn,
            'locations',
            'assigned_to',
          );
          await txn.execute(
            '''INSERT OR IGNORE INTO geofences
            (geofence_id,name,address,assigned_to,latitude,longitude,radius_meters,enabled,created_at,updated_at)
            SELECT id,name,address,${hasAssignedTo ? 'assigned_to' : 'NULL'},latitude,longitude,radius_meters,enabled,created_at,created_at FROM locations''',
          );
        }
        final oldEvents = await _tableExists(txn, 'events');
        if (oldEvents) {
          await txn.execute('''INSERT OR IGNORE INTO geofence_events
            (event_id,geofence_id,event_type,event_timestamp,latitude,longitude,accuracy_meters,radius_meters,
             distance_from_center_meters,battery_percentage,charging_status,network_type,device_id,
             sync_status,retry_count,last_error,created_at)
            SELECT id,geofence_id,event_type,event_time,latitude,longitude,accuracy_meters,radius_meters,
             distance_meters,battery_percentage,CASE WHEN is_charging=1 THEN 'charging' WHEN is_charging=0 THEN 'not_charging' END,
             network_type,device_id,CASE WHEN sync_status='synced' THEN 'synced' ELSE 'pending' END,
             attempts,last_error,created_at FROM events''');
        }
      }
      if (oldVersion < 7) {
        if (!await _columnExists(txn, 'geofence_events', 'sync_started_at')) {
          await txn.execute(
            'ALTER TABLE geofence_events ADD COLUMN sync_started_at TEXT',
          );
        }
        if (!await _columnExists(txn, 'attendance_events', 'sync_started_at')) {
          await txn.execute(
            'ALTER TABLE attendance_events ADD COLUMN sync_started_at TEXT',
          );
        }
      }
    });
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }

  Future<List<GeofenceConfig>> geofences() async {
    final db = await database;
    return (await db.query(
      'geofences',
      orderBy: 'created_at DESC',
    )).map(GeofenceConfig.fromMap).toList(growable: false);
  }

  Future<GeofenceConfig?> geofence(String id) async {
    final db = await database;
    final rows = await db.query(
      'geofences',
      where: 'geofence_id=?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GeofenceConfig.fromMap(rows.first);
  }

  Future<void> saveGeofence(GeofenceConfig config) async {
    config.validate();
    final db = await database;
    final values = config.toMap();
    await db.transaction((txn) async {
      // SQLite REPLACE is a DELETE followed by an INSERT. That DELETE fails
      // once events reference this geofence through an ON DELETE RESTRICT
      // foreign key. Update the existing row in place instead.
      final updated = await txn.update(
        'geofences',
        values,
        where: 'geofence_id=?',
        whereArgs: [config.id],
      );
      if (updated == 0) await txn.insert('geofences', values);
    });
  }

  Future<void> deleteGeofence(String id) async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM geofence_events WHERE geofence_id=?',
            [id],
          ),
        ) ??
        0;
    if (count > 0) {
      await db.update(
        'geofences',
        {'enabled': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'geofence_id=?',
        whereArgs: [id],
      );
    } else {
      await db.delete('geofences', where: 'geofence_id=?', whereArgs: [id]);
    }
  }

  Future<TransitionResult> insertTransition(GeofenceEventRecord event) async {
    final db = await database;
    return db.transaction((txn) async {
      final stateRows = await txn.query(
        'geofence_state',
        where: 'geofence_id=?',
        whereArgs: [event.geofenceId],
        limit: 1,
      );
      final previous = stateRows.isEmpty
          ? 'UNKNOWN'
          : '${stateRows.first['state']}';
      final current = event.eventType == GeofenceTransition.enter
          ? 'INSIDE'
          : 'OUTSIDE';
      final lastAt = stateRows.isEmpty
          ? null
          : DateTime.tryParse('${stateRows.first['last_event_at']}');
      final now = event.eventTimestamp.toUtc();

      final decision = TransitionPolicy.decide(
        previous: GeofenceState.values.byName(previous.toLowerCase()),
        current: GeofenceState.values.byName(current.toLowerCase()),
        callbackAt: now,
        lastEventAt: lastAt,
      );
      if (decision == TransitionDecision.duplicate) {
        await _upsertState(txn, event.geofenceId, current, lastAt, now);
        return const TransitionResult(false, 'duplicate_state');
      }
      if (decision == TransitionDecision.establishOutside) {
        await _upsertState(txn, event.geofenceId, current, null, now);
        return const TransitionResult(false, 'initial_outside_state');
      }
      if (decision == TransitionDecision.outOfOrder) {
        return const TransitionResult(false, 'out_of_order');
      }
      await txn.insert(
        'geofence_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _upsertState(txn, event.geofenceId, current, now, now);
      return const TransitionResult(true, 'inserted');
    });
  }

  Future<void> _upsertState(
    DatabaseExecutor db,
    String id,
    String state,
    DateTime? eventAt,
    DateTime callbackAt,
  ) => db.insert('geofence_state', {
    'geofence_id': id,
    'state': state,
    'last_event_at': eventAt?.toUtc().toIso8601String(),
    'last_callback_at': callbackAt.toUtc().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Map<String, Object?>>> eventPage({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''SELECT e.*, g.name AS geofence_name FROM geofence_events e
      JOIN geofences g ON g.geofence_id=e.geofence_id
      ORDER BY e.event_timestamp DESC LIMIT ? OFFSET ?''',
      [limit.clamp(1, 200), offset],
    );
  }

  Future<Map<String, int>> syncCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT sync_status,COUNT(*) count FROM geofence_events GROUP BY sync_status',
    );
    return {
      for (final row in rows)
        '${row['sync_status']}': (row['count'] as num).toInt(),
    };
  }

  Future<Map<String, DateTime?>> trackingActivity() async {
    final db = await database;
    final rows = await db.rawQuery('''SELECT
      MAX(event_timestamp) AS last_event_at,
      MAX(CASE WHEN sync_status='synced' THEN synced_at END) AS last_sync_at
      FROM geofence_events''');
    final row = rows.single;
    return {
      'lastEventAt': DateTime.tryParse('${row['last_event_at'] ?? ''}'),
      'lastSyncAt': DateTime.tryParse('${row['last_sync_at'] ?? ''}'),
    };
  }

  Future<void> insertAttendance(AttendanceEvent event) async {
    final db = await database;
    await db.transaction((txn) async {
      final previous = await txn.query(
        'attendance_events',
        columns: ['action', 'event_timestamp'],
        where: 'employee_id=?',
        whereArgs: [event.employeeId],
        orderBy: 'event_timestamp DESC, created_at DESC',
        limit: 1,
      );
      final expected = previous.isNotEmpty && previous.first['action'] == 'IN'
          ? AttendanceAction.checkOut
          : AttendanceAction.checkIn;
      if (event.action != expected) {
        throw StateError(
          expected == AttendanceAction.checkIn
              ? 'Check In is required before Check Out.'
              : 'Check Out is required before another Check In.',
        );
      }
      await txn.insert('attendance_events', event.toMap());
    });
  }

  Future<List<Map<String, Object?>>> attendanceHistory(
    String employeeId, {
    int limit = 100,
  }) async {
    final db = await database;
    return db.query(
      'attendance_events',
      where: 'employee_id=?',
      whereArgs: [employeeId],
      orderBy: 'event_timestamp DESC',
      limit: limit.clamp(1, 200),
    );
  }

  Future<AttendanceAction> nextAttendanceAction(String employeeId) async {
    final rows = await attendanceHistory(employeeId, limit: 1);
    return rows.isNotEmpty && rows.first['action'] == 'IN'
        ? AttendanceAction.checkOut
        : AttendanceAction.checkIn;
  }

  Future<List<Map<String, Object?>>> claimAttendanceBatch(
    String employeeId, {
    int limit = 50,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toUtc();
      final cutoff = now
          .subtract(AppConstants.syncLeaseTimeout)
          .toIso8601String();
      await txn.update(
        'attendance_events',
        {
          'sync_status': 'failed',
          'sync_started_at': null,
          'last_error': 'temporary: recovered interrupted synchronization',
        },
        where:
            "sync_status='syncing' AND (sync_started_at IS NULL OR sync_started_at<?)",
        whereArgs: [cutoff],
      );
      final rows = await txn.query(
        'attendance_events',
        where:
            "employee_id=? AND (sync_status='pending' OR (sync_status='failed' AND last_error LIKE 'temporary:%'))",
        whereArgs: [employeeId],
        orderBy: 'event_timestamp ASC',
        limit: limit,
      );
      for (final row in rows) {
        await txn.update(
          'attendance_events',
          {'sync_status': 'syncing', 'sync_started_at': now.toIso8601String()},
          where: 'attendance_id=?',
          whereArgs: [row['attendance_id']],
        );
      }
      return rows;
    });
  }

  Future<void> completeAttendanceSync(
    String id, {
    required bool accepted,
    required bool retryable,
    String? error,
    String? serverName,
  }) async {
    final db = await database;
    await db.update(
      'attendance_events',
      accepted
          ? {
              'sync_status': 'synced',
              'last_error': null,
              'synced_at': DateTime.now().toUtc().toIso8601String(),
              'sync_started_at': null,
              'server_name': serverName,
            }
          : {
              'sync_status': 'failed',
              'retry_count': 1,
              'last_error':
                  '${retryable ? 'temporary' : 'permanent'}: ${_redact(error ?? 'Rejected')}',
              'sync_started_at': null,
            },
      where: 'attendance_id=?',
      whereArgs: [id],
    );
  }

  Future<void> releaseAttendanceBatch(
    String reason, {
    required Iterable<String> attendanceIds,
  }) async {
    final db = await database;
    final ids = attendanceIds.toList(growable: false);
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE attendance_events SET sync_status='failed',sync_started_at=NULL,last_error=? WHERE sync_status='syncing' AND attendance_id IN ($marks)",
      ['temporary: ${_redact(reason)}', ...ids],
    );
  }

  Future<List<Map<String, Object?>>> claimSyncBatch({
    int limit = AppConstants.syncBatchSize,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toUtc();
      final cutoff = now
          .subtract(AppConstants.syncLeaseTimeout)
          .toIso8601String();
      await txn.update(
        'geofence_events',
        {
          'sync_status': 'failed',
          'sync_started_at': null,
          'last_error': 'temporary: recovered interrupted synchronization',
        },
        where:
            "sync_status='syncing' AND (sync_started_at IS NULL OR sync_started_at<?)",
        whereArgs: [cutoff],
      );
      final rows = await txn.query(
        'geofence_events',
        where:
            "sync_status='pending' OR (sync_status='failed' AND last_error LIKE 'temporary:%')",
        orderBy: 'event_timestamp ASC',
        limit: limit,
      );
      if (rows.isNotEmpty) {
        final ids = rows.map((e) => e['event_id']).toList();
        final marks = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          "UPDATE geofence_events SET sync_status='syncing',sync_started_at=? WHERE event_id IN ($marks)",
          [now.toIso8601String(), ...ids],
        );
      }
      return rows;
    });
  }

  Future<void> markSynced(String id, DateTime serverTime) async {
    final db = await database;
    await db.update(
      'geofence_events',
      {
        'sync_status': 'synced',
        'last_error': null,
        'synced_at': serverTime.toUtc().toIso8601String(),
        'sync_started_at': null,
      },
      where: 'event_id=?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncFailed(
    String id,
    String error, {
    required bool retryable,
  }) async {
    final db = await database;
    await db.rawUpdate(
      '''UPDATE geofence_events SET sync_status='failed', retry_count=retry_count+1,
      last_error=?, sync_started_at=NULL WHERE event_id=?''',
      ['${retryable ? 'temporary' : 'permanent'}: ${_redact(error)}', id],
    );
  }

  Future<void> releaseSyncBatch(
    String reason, {
    required Iterable<String> eventIds,
  }) async {
    final db = await database;
    final ids = eventIds.toList(growable: false);
    if (ids.isEmpty) return;
    final normalized = reason.startsWith('temporary:')
        ? reason
        : 'temporary: $reason';
    final marks = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE geofence_events SET sync_status='failed',sync_started_at=NULL,last_error=? WHERE sync_status='syncing' AND event_id IN ($marks)",
      [_redact(normalized), ...ids],
    );
  }

  Future<void> diagnostic(
    String level,
    String category,
    String message, [
    String? details,
  ]) async {
    final db = await database;
    await db.insert('diagnostics', {
      'level': level,
      'category': category,
      'message': message,
      'details': details == null ? null : _redact(details),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> diagnostics({int limit = 100}) async {
    final db = await database;
    return db.query(
      'diagnostics',
      orderBy: 'created_at DESC',
      limit: limit.clamp(1, 500),
    );
  }

  Future<int> pruneSyncedBefore(DateTime cutoff) async {
    final db = await database;
    return db.delete(
      'geofence_events',
      where: "sync_status='synced' AND synced_at<?",
      whereArgs: [cutoff.toUtc().toIso8601String()],
    );
  }

  String _redact(String value) => value
      .replaceAll(
        RegExp(r'token\s+[^\s]+', caseSensitive: false),
        'token [REDACTED]',
      )
      .replaceAll(
        RegExp(r'api[_ -]?secret[=: ]+[^,\s]+', caseSensitive: false),
        'api_secret=[REDACTED]',
      );

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
