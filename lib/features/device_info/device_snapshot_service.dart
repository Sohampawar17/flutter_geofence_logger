import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceSnapshot {
  final String deviceId;
  final int? batteryPercentage;
  final String? chargingStatus;
  final String? networkType;
  final bool? internetAvailable;
  final String? androidVersion;
  final String? manufacturer;
  final String? model;

  const DeviceSnapshot({
    required this.deviceId,
    this.batteryPercentage,
    this.chargingStatus,
    this.networkType,
    this.internetAvailable,
    this.androidVersion,
    this.manufacturer,
    this.model,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'battery_percentage': batteryPercentage,
      'charging_status': chargingStatus,
      'network_type': networkType,
      'internet_available': internetAvailable,
      'android_version': androidVersion,
      'manufacturer': manufacturer,
      'model': model,
    };
  }
}

class DeviceSnapshotService {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceSnapshot> capture() async {
    // ------------------------------------
    // 1. UNIQUE INSTALLATION ID
    // ------------------------------------
    String id;
    try {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('installation_id') ?? '';
      if (id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString('installation_id', id);
      }
    } catch (_) {
      // This should only be needed if Android cannot initialize the preferences
      // plugin in a background callback. Keep recording the event so the
      // failure of optional telemetry never suppresses ENTER/EXIT history.
      id = 'unavailable-${const Uuid().v4()}';
    }

    // ------------------------------------
    // 2. DEFAULT VALUES
    // ------------------------------------
    int? battery;
    String? charging;
    String? network;
    bool? internet;
    String? version;
    String? manufacturer;
    String? model;

    // ------------------------------------
    // 3. BATTERY INFORMATION
    // ------------------------------------
    try {
      battery = await _battery.batteryLevel.timeout(const Duration(seconds: 2));

      if (battery < 0 || battery > 100) {
        battery = null;
      }

      final state = await _battery.batteryState.timeout(
        const Duration(seconds: 2),
      );

      if (state == BatteryState.charging) {
        charging = 'charging';
      } else if (state == BatteryState.full) {
        charging = 'full';
      } else if (state == BatteryState.discharging) {
        charging = 'discharging';
      } else {
        charging = 'unknown';
      }
    } catch (_) {}

    // ------------------------------------
    // 4. NETWORK INFORMATION
    // ------------------------------------
    try {
      final connections = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 3),
      );

      network = connections.map((item) => item.name).join(',');

      internet = !connections.every((item) => item == ConnectivityResult.none);
    } catch (_) {}

    // ------------------------------------
    // 5. ANDROID DEVICE INFORMATION
    // ------------------------------------
    try {
      final android = await _deviceInfo.androidInfo.timeout(
        const Duration(seconds: 3),
      );

      version = '${android.version.release} (SDK ${android.version.sdkInt})';

      manufacturer = android.manufacturer;
      model = android.model;
    } catch (_) {}

    // ------------------------------------
    // 6. RETURN DEVICE SNAPSHOT
    // ------------------------------------
    return DeviceSnapshot(
      deviceId: id,
      batteryPercentage: battery,
      chargingStatus: charging,
      networkType: network,
      internetAvailable: internet,
      androidVersion: version,
      manufacturer: manufacturer,
      model: model,
    );
  }
}
