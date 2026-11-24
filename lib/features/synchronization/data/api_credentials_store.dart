import 'package:flutter/services.dart';

class ApiCredentials {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  const ApiCredentials(this.baseUrl, this.apiKey, this.apiSecret);
  bool get configured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && apiSecret.isNotEmpty;
}

class ApiCredentialsStore {
  static const _channel = MethodChannel(
    'com.geopulse.geofence_logger/background',
  );

  Future<ApiCredentials> read() async {
    final value =
        await _channel.invokeMapMethod<String, String>('readApiCredentials') ??
        const {};
    return ApiCredentials(
      value['baseUrl'] ?? '',
      value['apiKey'] ?? '',
      value['apiSecret'] ?? '',
    );
  }

  Future<void> write(ApiCredentials value) =>
      _channel.invokeMethod('writeApiCredentials', {
        'baseUrl': value.baseUrl,
        'apiKey': value.apiKey,
        'apiSecret': value.apiSecret,
      });

  Future<void> clear() => _channel.invokeMethod('clearApiCredentials');
}
