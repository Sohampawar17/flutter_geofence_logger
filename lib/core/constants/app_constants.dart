class AppConstants {
  static const defaultSiteUrl = 'https://sanpra.erpkey.in';
  static const databaseName = 'geofence_events.db';
  static const databaseVersion = 7;
  static const syncLeaseTimeout = Duration(minutes: 15);
  static const syncedEventRetentionDays = 90;
  static const defaultRadiusMeters = 200.0;
  static const minRadiusMeters = 100.0;
  static const maxRadiusMeters = 10000.0;
  // Android treats this as a best-effort delivery target, not a guarantee.
  // Keep it short enough to observe brief field visits while avoiding the
  // effectively immediate (and battery-heavy) zero-duration setting.
  static const geofenceNotificationResponsiveness = Duration(seconds: 5);
  static const syncBatchSize = 50;
  static const syncTaskName = 'geopulse.sync.pending';
  static const syncUniqueName = 'geopulse-sync';
  static const periodicSyncUniqueName = 'geopulse-periodic-sync';
}
