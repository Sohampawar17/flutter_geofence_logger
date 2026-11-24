import 'dart:developer' as developer;

class ApiLogger {
  static const _name = 'GeoPulse.API';

  static void request(String method, Uri uri, {String? details}) {
    developer.log(
      '--> $method ${_safeUri(uri)}${details == null ? '' : ' $details'}',
      name: _name,
    );
  }

  static void response(
    String method,
    Uri uri,
    int statusCode,
    String body,
    Duration elapsed,
  ) {
    developer.log(
      '<-- $method ${_safeUri(uri)} $statusCode '
      '(${elapsed.inMilliseconds}ms) ${_safeBody(body)}',
      name: _name,
      level: statusCode >= 400 ? 1000 : 800,
    );
  }

  static void error(
    String method,
    Uri uri,
    Object error,
    StackTrace stackTrace,
    Duration elapsed,
  ) {
    developer.log(
      '<!! $method ${_safeUri(uri)} (${elapsed.inMilliseconds}ms) $error',
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _safeUri(Uri uri) => uri.replace(query: '').toString();

  static String _safeBody(String source) {
    final sensitiveValue = RegExp(
      r'("(?:api_key|api_secret|pwd|password|company_email|personal_email|cell_number|emergency_phone_number)"\s*:\s*")[^"]*"',
      caseSensitive: false,
    );
    var value = source
        .replaceAllMapped(
          sensitiveValue,
          (match) => '${match.group(1)}<redacted>"',
        )
        .replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (value.length > 1000) value = '${value.substring(0, 1000)}...';
    return value;
  }
}
