import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/permissions/monitoring_status.dart';
import '../features/device_info/device_snapshot_service.dart';
import '../features/authentication/data/employee_auth_service.dart';
import '../features/attendance/data/attendance_service.dart';
import '../features/attendance/data/mobile_api_service.dart';
import '../features/attendance/domain/attendance_event.dart';
import '../features/event_logs/data/app_database.dart';
import '../features/geofence/data/geofence_service.dart';
import '../features/geofence/domain/geofence_config.dart';
import '../features/synchronization/background_sync.dart';
import '../features/synchronization/data/api_credentials_store.dart';
import '../features/synchronization/data/sync_service.dart';

class AppController extends ChangeNotifier {
  final AppDatabase database;
  final GeofenceService geofenceService;
  final SyncService syncService;
  final BackgroundSyncScheduler scheduler;
  final MonitoringStatusService statusService;
  final EmployeeAuthService authService;
  final AttendanceService attendanceService;
  final MobileApiService mobileApiService;

  AppController({
    AppDatabase? database,
    GeofenceService? geofenceService,
    SyncService? syncService,
    BackgroundSyncScheduler? scheduler,
    MonitoringStatusService? statusService,
    EmployeeAuthService? authService,
    AttendanceService? attendanceService,
    MobileApiService? mobileApiService,
  }) : database = database ?? AppDatabase.instance,
       geofenceService = geofenceService ?? GeofenceService(),
       syncService = syncService ?? SyncService(),
       scheduler = scheduler ?? BackgroundSyncScheduler(),
       statusService = statusService ?? MonitoringStatusService(),
       authService = authService ?? EmployeeAuthService(),
       attendanceService = attendanceService ?? AttendanceService(),
       mobileApiService = mobileApiService ?? MobileApiService();

  bool loading = true;
  bool busy = false;
  String? error;
  String? notice;
  List<GeofenceConfig> geofences = const [];
  List<Map<String, Object?>> events = const [];
  List<Map<String, Object?>> diagnostics = const [];
  Map<String, int> syncCounts = const {};
  MonitoringStatus? monitoringStatus;
  DeviceSnapshot? device;
  DateTime? lastSuccessfulSync;
  DateTime? lastRecordedEvent;
  DateTime? lastRegistrationAttempt;
  String? registrationError;
  EmployeeSession session = const EmployeeSession(
    baseUrl: '',
    apiKey: '',
    apiSecret: '',
    employeeName: '',
    employeeId: '',
  );
  List<Map<String, Object?>> attendance = const [];
  Map<String, dynamic> dashboard = const {};
  Map<String, dynamic> deviceEnrollment = const {};
  String? deviceEnrollmentError;
  Map<String, dynamic> monthlyAttendance = const {};
  List<Map<String, dynamic>> assignedLocations = const [];
  bool _refreshingMobileData = false;
  bool _resuming = false;
  AttendanceAction nextAttendanceAction = AttendanceAction.checkIn;
  int eventOffset = 0;
  static const pageSize = 50;

  Future<void> initialize() async {
    try {
      session = await authService.read();
      if (session.authenticated) {
        await ApiCredentialsStore().write(
          ApiCredentials(session.baseUrl, session.apiKey, session.apiSecret),
        );
      }
      await geofenceService.initialize();
      await refresh();
      if (session.authenticated) {
        await _ensureEmployeeDevice();
        unawaited(retryPendingAttendance());
      }
      await scheduler.initialize();
      if (monitoringStatus?.ready == true) {
        await _reconcileGeofences();
        await refreshStatus();
      }
      if (session.authenticated) unawaited(scheduler.enqueue());
    } catch (e, stack) {
      error = 'Startup check failed: $e';
      await database
          .diagnostic('error', 'startup', '$e', '$stack')
          .catchError((_) {});
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool resetPage = false, bool loadRemote = true}) async {
    if (resetPage) eventOffset = 0;
    geofences = await database.geofences();
    events = await database.eventPage(limit: pageSize, offset: eventOffset);
    syncCounts = await database.syncCounts();
    final activity = await database.trackingActivity();
    lastRecordedEvent = activity['lastEventAt'];
    lastSuccessfulSync = activity['lastSyncAt'];
    diagnostics = await database.diagnostics(limit: 50);
    if (session.authenticated) {
      attendance = await database.attendanceHistory(session.employeeId);
      nextAttendanceAction = await database.nextAttendanceAction(
        session.employeeId,
      );
      if (loadRemote) unawaited(_refreshMobileData());
    } else {
      attendance = const [];
      nextAttendanceAction = AttendanceAction.checkIn;
    }
    device = await DeviceSnapshotService().capture();
    await refreshStatus();
    notifyListeners();
  }

  Future<void> resumeMonitoring() async {
    if (_resuming) return;
    _resuming = true;
    try {
      await refresh(loadRemote: false);
      if (monitoringStatus?.ready == true) {
        await _reconcileGeofences();
        await refreshStatus();
      }
    } catch (e, stack) {
      await database
          .diagnostic('error', 'monitoring_resume', '$e', '$stack')
          .catchError((_) {});
      error = 'Could not restore location monitoring: $e';
    } finally {
      _resuming = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromServer() async {
    await _refreshMobileData(showErrors: true);
    await refresh(loadRemote: false);
  }

  Future<void> loadAttendancePeriod({
    required int month,
    required int year,
  }) async => _guard(() async {
    monthlyAttendance = await mobileApiService.getAttendanceList(
      month: month,
      year: year,
    );
  });

  Future<void> _refreshMobileData({bool showErrors = false}) async {
    if (_refreshingMobileData || !session.authenticated) return;
    _refreshingMobileData = true;
    Object? firstError;
    try {
      final now = DateTime.now();
      // Some small Frappe deployments close connections when these requests
      // arrive simultaneously. They are independent, so load them in sequence
      // and retain the last successful value when one request fails.
      dashboard = await mobileApiService.getDashboard().catchError((
        error,
        stack,
      ) async {
        firstError ??= error;
        await _recordMobileApiError('get_dashboard', error, stack);
        return dashboard;
      });
      monthlyAttendance = await mobileApiService
          .getAttendanceList(month: now.month, year: now.year)
          .catchError((error, stack) async {
            firstError ??= error;
            await _recordMobileApiError('get_attendance_list', error, stack);
            return monthlyAttendance;
          });
      final locations = await mobileApiService.getLocations().catchError((
        error,
        stack,
      ) async {
        firstError ??= error;
        await _recordMobileApiError('get_locations', error, stack);
        return assignedLocations;
      });
      assignedLocations = locations
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
      await _storeAssignedGeofences(assignedLocations);
      final next = '${dashboard['next_log_type'] ?? ''}'.toUpperCase();
      if (next == 'IN' || next == 'OUT') {
        nextAttendanceAction = next == 'IN'
            ? AttendanceAction.checkIn
            : AttendanceAction.checkOut;
      }
      if (showErrors && firstError != null) {
        error = firstError is AppException
            ? (firstError as AppException).message
            : '$firstError'.replaceFirst('Bad state: ', '');
      }
      notifyListeners();
    } catch (e, stack) {
      await _recordMobileApiError('refresh', e, stack);
    } finally {
      _refreshingMobileData = false;
    }
  }

  Future<void> _storeAssignedGeofences(
    List<Map<String, dynamic>> locations,
  ) async {
    final now = DateTime.now().toUtc();
    final marker = 'api:${session.employeeId}';
    final existing = {
      for (final item in await database.geofences()) item.id: item,
    };
    final receivedIds = <String>{};

    for (final raw in locations) {
      final id = '${raw['geofence_id'] ?? ''}'.trim();
      final name = '${raw['location_name'] ?? ''}'.trim();
      final latitude = _number(raw['latitude']);
      final longitude = _number(raw['longitude']);
      final radius = _number(raw['radius_meters']);
      if (id.isEmpty ||
          name.isEmpty ||
          latitude == null ||
          longitude == null ||
          radius == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180 ||
          radius < AppConstants.minRadiusMeters ||
          radius > AppConstants.maxRadiusMeters) {
        await database.diagnostic(
          'warning',
          'mobile_api.get_locations',
          'Ignored an invalid assigned location.',
          'geofence_id=$id',
        );
        continue;
      }
      receivedIds.add(id);
      final previous = existing[id];
      final address = '${raw['address'] ?? ''}'.trim();
      await database.saveGeofence(
        GeofenceConfig(
          id: id,
          name: name,
          address: address.isEmpty ? null : address,
          assignedTo: marker,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radius,
          enabled: true,
          createdAt: previous?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    for (final item in existing.values) {
      if (item.assignedTo == marker && !receivedIds.contains(item.id)) {
        await geofenceService.unregister(item.id).catchError((_) {});
        await database.deleteGeofence(item.id);
      }
    }

    geofences = await database.geofences();
    if (monitoringStatus?.ready == true) {
      await _reconcileGeofences();
      await refreshStatus();
    }
  }

  double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

  Future<void> _recordMobileApiError(
    String method,
    Object error,
    StackTrace stack,
  ) => database
      .diagnostic('warning', 'mobile_api.$method', '$error', '$stack')
      .catchError((_) {});

  Future<void> refreshStatus() async {
    var registered = 0;
    try {
      registered = (await geofenceService.registered()).length;
    } catch (_) {}
    monitoringStatus = await statusService.inspect(registeredCount: registered);
  }

  Future<void> _reconcileGeofences() async {
    lastRegistrationAttempt = DateTime.now().toUtc();
    try {
      await geofenceService.reconcile(geofences);
      registrationError = null;
      await database.diagnostic(
        'info',
        'geofence_registration',
        'Registration reconciliation completed.',
        'configured=${geofences.where((item) => item.enabled).length}',
      );
    } catch (error) {
      registrationError = '$error';
      await database.diagnostic(
        'error',
        'geofence_registration',
        'Registration reconciliation failed.',
        '$error',
      );
      rethrow;
    }
  }

  Future<void> requestMonitoringPermissions() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw const AppException('Turn on Android location services first.');
    }
    var foreground = await Permission.location.status;
    if (!foreground.isGranted) {
      foreground = await Permission.location.request();
    }
    if (!foreground.isGranted) {
      if (foreground.isPermanentlyDenied || foreground.isRestricted) {
        await openAppSettings();
      }
      throw const AppException('Precise location permission is required.');
    }
    var background = await Permission.locationAlways.status;
    if (!background.isGranted) {
      background = await Permission.locationAlways.request();
    }
    if (!background.isGranted) {
      // Android 11+ only offers "Allow all the time" from the app's
      // Location settings. This may be reported as a regular denial, so open
      // Settings for every unsuccessful background-location request.
      await openAppSettings();
      throw const AppException(
        'Choose “Allow all the time” for reliable background geofencing.',
      );
    }
    var notifications = await Permission.notification.status;
    if (!notifications.isGranted) {
      notifications = await Permission.notification.request();
    }
    if (!notifications.isGranted) {
      notice =
          'Monitoring can continue, but attendance and tracking alerts are disabled.';
    }
    await refreshStatus();
    notifyListeners();
  }

  Future<void> saveGeofence({
    String? id,
    required String name,
    String? address,
    String? assignedTo,
    required double latitude,
    required double longitude,
    double radiusMeters = AppConstants.defaultRadiusMeters,
    bool enabled = true,
  }) async => _guard(() async {
    final existing = id == null ? null : await database.geofence(id);
    final now = DateTime.now().toUtc();
    final config = GeofenceConfig(
      id: id ?? 'geo-${const Uuid().v4()}',
      name: name.trim(),
      address: address?.trim(),
      assignedTo: assignedTo?.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      enabled: enabled,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    config.validate();
    if (enabled) await requestMonitoringPermissions();
    if (existing?.enabled == true) {
      await geofenceService.unregister(config.id).catchError((_) {});
    }
    try {
      if (enabled) await geofenceService.register(config);
      await database.saveGeofence(config);
    } catch (e) {
      if (existing?.enabled == true) {
        await geofenceService.register(existing!).catchError((_) {});
      }
      rethrow;
    }
    notice = existing == null
        ? 'Location monitoring created.'
        : 'Location monitoring updated.';
    await refresh(resetPage: true);
  });

  Future<void> setEnabled(GeofenceConfig config, bool enabled) async =>
      _guard(() async {
        if (enabled) {
          await requestMonitoringPermissions();
          await geofenceService.register(config.copyWith(enabled: true));
        } else {
          await geofenceService.unregister(config.id).catchError((_) {});
        }
        await database.saveGeofence(
          config.copyWith(enabled: enabled, updatedAt: DateTime.now().toUtc()),
        );
        await refresh();
      });

  Future<void> deleteGeofence(GeofenceConfig config) async => _guard(() async {
    await geofenceService.unregister(config.id).catchError((_) {});
    await database.deleteGeofence(config.id);
    notice = 'Monitoring stopped. Historical events were preserved.';
    await refresh(resetPage: true);
  });

  Future<geo.Position> currentPosition() => geo.Geolocator.getCurrentPosition(
    locationSettings: const geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );

  Future<void> synchronize() async => _guard(() async {
    final result = await syncService.synchronize();
    await attendanceService.synchronize();
    if (result.uploaded > 0) lastSuccessfulSync = DateTime.now();
    final message =
        result.message ??
        'Uploaded ${result.uploaded}; failed ${result.failed}.';
    if (result.failed > 0) {
      error = message;
    } else {
      notice = message;
    }
    await refresh();
  });

  Future<void> retryPendingAttendance() async {
    if (!session.authenticated) return;
    try {
      await attendanceService.synchronize();
      await refresh();
    } catch (e, stack) {
      await database
          .diagnostic('warning', 'attendance_sync', '$e', '$stack')
          .catchError((_) {});
    }
  }

  Future<void> login(String baseUrl, String username, String password) async =>
      _guard(() async {
        session = await authService.login(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        final snapshot = await DeviceSnapshotService().capture();
        device = snapshot;
        await ApiCredentialsStore().write(
          ApiCredentials(session.baseUrl, session.apiKey, session.apiSecret),
        );
        await scheduler.initialize();
        await _ensureEmployeeDevice();
        notice = 'Welcome, ${session.employeeName}.';
        await refresh();
      });

  Future<void> logout() async => _guard(() async {
    await authService.logout();
    await ApiCredentialsStore().clear();
    session = await authService.read();
    deviceEnrollment = const {};
    deviceEnrollmentError = null;
    notice = null;
    await refresh(loadRemote: false);
  });

  Future<void> recordAttendance(
    AttendanceAction action,
  ) async => _guard(() async {
    await attendanceService.record(action);
    var synchronized = true;
    try {
      await attendanceService.synchronize();
    } catch (_) {
      // The locally committed event remains pending for a safe retry.
      synchronized = false;
    }
    notice = synchronized
        ? (action == AttendanceAction.checkIn
              ? 'Checked in successfully.'
              : 'Checked out successfully.')
        : 'Attendance saved on this device. It will retry when the server is available.';
    await refresh();
  });

  Future<void> enrollDevice() async => _guard(() async {
    await _ensureEmployeeDevice(throwOnFailure: true);
    notice = 'This device is enrolled for ${session.employeeName}.';
  });

  Future<void> _ensureEmployeeDevice({bool throwOnFailure = false}) async {
    if (!session.authenticated) return;
    final snapshot = device ?? await DeviceSnapshotService().capture();
    device = snapshot;
    try {
      deviceEnrollment = await mobileApiService.ensureEmployeeDevice(
        deviceId: snapshot.deviceId,
        deviceName: '${snapshot.manufacturer ?? ''} ${snapshot.model ?? ''}'
            .trim(),
      );
      deviceEnrollmentError = null;
    } catch (e, stack) {
      await _recordMobileApiError('ensure_employee_device', e, stack);
      deviceEnrollment = const {};
      deviceEnrollmentError = e is AppException
          ? e.message
          : '$e'.replaceFirst('Bad state: ', '');
      if (throwOnFailure) rethrow;
    }
  }

  Future<void> nextPage() async {
    eventOffset += pageSize;
    final page = await database.eventPage(limit: pageSize, offset: eventOffset);
    if (page.isEmpty) eventOffset = (eventOffset - pageSize).clamp(0, 1 << 30);
    events = page.isEmpty ? events : page;
    notifyListeners();
  }

  Future<void> previousPage() async {
    eventOffset = (eventOffset - pageSize).clamp(0, 1 << 30);
    events = await database.eventPage(limit: pageSize, offset: eventOffset);
    notifyListeners();
  }

  Future<void> pruneSynced({required int retentionDays}) async =>
      _guard(() async {
        final removed = await database.pruneSyncedBefore(
          DateTime.now().subtract(Duration(days: retentionDays)),
        );
        notice =
            'Removed $removed synchronized events. Pending events were kept.';
        await refresh(resetPage: true);
      });

  Future<void> _guard(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await operation();
    } catch (e, stack) {
      error = e is AppException
          ? e.message
          : '$e'.replaceFirst('Bad state: ', '');
      await database
          .diagnostic('error', 'operation', '$e', '$stack')
          .catchError((_) {});
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
