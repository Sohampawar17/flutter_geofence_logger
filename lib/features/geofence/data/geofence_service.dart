import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:native_geofence/native_geofence.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geofence_debug_log.dart';
import '../../device_info/device_snapshot_service.dart';
import '../../event_logs/data/app_database.dart';
import '../../event_logs/domain/geofence_event.dart';
import '../../synchronization/background_sync.dart';
import '../domain/geofence_config.dart';
import '../domain/geofence_location_evaluator.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> nativeGeofenceCallback(GeofenceCallbackParams params) async {
  await _processNativeGeofenceCallback(params);
}

Future<void> _processNativeGeofenceCallback(
  GeofenceCallbackParams params, {
  int attempt = 1,
}) async {
  // Native geofence callbacks run in a background isolate. Register Flutter
  // plugins before accessing sqflite, shared_preferences, battery, or network.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  GeofenceDebugLog.info(
    'Background callback awake: event=${params.event.name}, '
    'geofences=${params.geofences.map((item) => item.id).join(',')}, '
    'callbackLocation=${params.location?.latitude},${params.location?.longitude}',
  );
  if (params.event != GeofenceEvent.enter &&
      params.event != GeofenceEvent.exit) {
    GeofenceDebugLog.info('Ignoring unsupported event ${params.event.name}.');
    return;
  }
  final database = AppDatabase.instance;
  var savedEvent = false;
  try {
    final device = await DeviceSnapshotService().capture();
    geo.Position? lastKnown;
    try {
      lastKnown = await geo.Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
      );
      GeofenceDebugLog.info(
        'Last known location: ${lastKnown?.latitude},${lastKnown?.longitude}; '
        'accuracy=${lastKnown?.accuracy.toStringAsFixed(1)}m.',
      );
    } catch (error) {
      GeofenceDebugLog.info('Last known location unavailable: $error');
    }
    for (final fence in params.geofences) {
      final config = await database.geofence(fence.id);
      if (config == null) {
        GeofenceDebugLog.info(
          'Ignoring ${fence.id}: no matching geofence exists in the database.',
        );
        continue;
      }
      if (!config.enabled) {
        GeofenceDebugLog.info('Ignoring ${fence.id}: geofence is disabled.');
        continue;
      }
      final callbackLocation = params.location;
      final latitude = callbackLocation?.latitude ?? lastKnown?.latitude;
      final longitude = callbackLocation?.longitude ?? lastKnown?.longitude;
      final evaluation = latitude == null || longitude == null
          ? null
          : GeofenceLocationEvaluator.evaluate(
              geofence: config,
              latitude: latitude,
              longitude: longitude,
            );
      final now = DateTime.now().toUtc();
      final type = params.event == GeofenceEvent.enter
          ? GeofenceTransition.enter
          : GeofenceTransition.exit;
      GeofenceDebugLog.info(
        '${type.name.toUpperCase()} check for "${config.name}": '
        'device=$latitude,$longitude; center=${config.latitude},${config.longitude}; '
        'radius=${config.radiusMeters.toStringAsFixed(1)}m; '
        'distance=${evaluation?.distanceMeters.toStringAsFixed(1) ?? 'unknown'}m; '
        'calculatedState=${evaluation == null ? 'UNKNOWN' : (evaluation.isInside ? 'INSIDE' : 'OUTSIDE')}.',
      );
      final result = await database.insertTransition(
        GeofenceEventRecord(
          eventId: const Uuid().v4(),
          geofenceId: config.id,
          eventType: type,
          eventTimestamp: now,
          latitude: latitude,
          longitude: longitude,
          // The plugin does not expose accuracy for Android's triggering
          // location. Only associate accuracy with the supplementary last
          // known fix when that fix supplied the coordinates.
          accuracyMeters: callbackLocation == null ? lastKnown?.accuracy : null,
          radiusMeters: config.radiusMeters,
          distanceFromCenterMeters: evaluation?.distanceMeters,
          batteryPercentage: device.batteryPercentage,
          chargingStatus: device.chargingStatus,
          networkType: device.networkType,
          internetAvailable: device.internetAvailable,
          deviceId: device.deviceId,
          androidVersion: device.androidVersion,
          deviceManufacturer: device.manufacturer,
          deviceModel: device.model,
          backgroundEvent: true,
          syncStatus: SyncStatus.pending,
          retryCount: 0,
          createdAt: now,
        ),
      );
      if (result.inserted) {
        savedEvent = true;
        GeofenceDebugLog.info(
          '${type.name.toUpperCase()} accepted and saved for ${config.id}; '
          'showing notification.',
        );
        try {
          await NotificationService.initialize();
          await NotificationService.event(
            type == GeofenceTransition.enter ? 'ENTER' : 'EXIT',
            config.name,
          );
        } catch (error) {
          // Notification permission/plugin failures are nonessential. The
          // event is already durable and must still be queued for upload.
          await database.diagnostic(
            'warning',
            'notification',
            'Event notification unavailable.',
            '$error',
          );
        }
      } else {
        GeofenceDebugLog.info(
          '${type.name.toUpperCase()} not saved for ${config.id}: ${result.reason}',
        );
        await database.diagnostic(
          'info',
          'transition',
          result.reason,
          'geofence=${config.id}',
        );
      }
    }
    if (savedEvent) {
      try {
        await BackgroundSyncScheduler().enqueue();
      } catch (error) {
        // A headless Flutter engine does not always contain the activity-owned
        // custom MethodChannel. The native periodic worker remains the durable
        // fallback; do not retry or duplicate an already-saved transition.
        await database.diagnostic(
          'warning',
          'sync_schedule',
          'Immediate background sync could not be queued.',
          '$error',
        );
      }
    }
  } catch (error, stack) {
    GeofenceDebugLog.error(
      'Background geofence callback failed.',
      error,
      stack,
    );
    if (attempt < 3) {
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      return _processNativeGeofenceCallback(params, attempt: attempt + 1);
    }
    await database
        .diagnostic(
          'error',
          'geofence_callback',
          'Callback failed after 3 attempts: $error',
          '$stack',
        )
        .catchError((_) {});
  }
}

class GeofenceService {
  final NativeGeofenceManager _manager = NativeGeofenceManager.instance;

  Future<void> initialize() async {
    GeofenceDebugLog.info('Initializing OS geofence monitoring.');
    await _manager.initialize();
    GeofenceDebugLog.info('OS geofence monitoring is ready.');
  }

  Geofence _native(GeofenceConfig config) => Geofence(
    id: config.id,
    location: Location(latitude: config.latitude, longitude: config.longitude),
    radiusMeters: config.radiusMeters,
    triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
    iosSettings: const IosGeofenceSettings(initialTrigger: false),
    androidSettings: const AndroidGeofenceSettings(
      // ENTER establishes UNKNOWN -> INSIDE. An initial EXIT only establishes
      // OUTSIDE and is never persisted as a fabricated transition.
      initialTriggers: {GeofenceEvent.enter, GeofenceEvent.exit},
      // A long responsiveness window can miss an ENTER followed by an EXIT
      // during a short site visit. Android still batches callbacks when the
      // device is idle, but this asks Play Services to deliver active-device
      // transitions promptly enough for field counting.
      notificationResponsiveness:
          AppConstants.geofenceNotificationResponsiveness,
    ),
  );

  Future<void> register(GeofenceConfig config) async {
    config.validate();
    GeofenceDebugLog.info(
      'Registering "${config.name}" (${config.id}): '
      'center=${config.latitude},${config.longitude}; '
      'radius=${config.radiusMeters.toStringAsFixed(1)}m.',
    );
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _manager.createGeofence(_native(config), nativeGeofenceCallback);
        final active = await _manager.getRegisteredGeofences();
        if (!active.any((item) => item.id == config.id)) {
          throw StateError(
            'Android did not confirm the geofence registration.',
          );
        }
        GeofenceDebugLog.info(
          'Registration confirmed for ${config.id}; total active=${active.length}.',
        );
        return;
      } catch (error) {
        lastError = error;
        GeofenceDebugLog.info(
          'Registration attempt $attempt/2 failed for ${config.id}: $error',
        );
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    throw StateError(
      'Android geofence registration failed after 2 attempts: $lastError',
    );
  }

  Future<void> unregister(String id) async {
    GeofenceDebugLog.info('Removing geofence $id from OS monitoring.');
    await _manager.removeGeofenceById(id);
    GeofenceDebugLog.info('Removed geofence $id.');
  }

  Future<List<ActiveGeofence>> registered() =>
      _manager.getRegisteredGeofences();

  Future<void> reconcile(List<GeofenceConfig> configs) async {
    final active = await registered();
    final enabled = {
      for (final item in configs.where((item) => item.enabled)) item.id: item,
    };
    GeofenceDebugLog.info(
      'Reconciling geofences: configured=${configs.length}, '
      'enabled=${enabled.length}, OS active=${active.length}.',
    );
    final failures = <String>[];
    for (final item in active) {
      if (!enabled.containsKey(item.id)) {
        try {
          await unregister(item.id);
        } catch (error) {
          failures.add('remove ${item.id}: $error');
        }
      }
    }
    for (final item in enabled.values) {
      // The plugin's persisted list can survive while Android/Play Services
      // has lost the live registration (for example after an APK replacement,
      // reboot recovery failure, or Play Services reset). Re-registering is
      // idempotent for the same ID and restores the actual OS geofence. Any
      // resulting initial callback is safely filtered by TransitionPolicy.
      try {
        await register(item);
      } catch (error) {
        failures.add('register ${item.id}: $error');
      }
    }
    final reconciled = await registered();
    GeofenceDebugLog.info(
      'Reconciliation complete; OS monitoring '
      '${reconciled.map((item) => item.id).join(',')}.',
    );
    if (failures.isNotEmpty) {
      throw StateError(failures.join('; '));
    }
  }
}
