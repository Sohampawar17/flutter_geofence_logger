import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';

class ApiError {
  static AppException response(
    int statusCode,
    String body, {
    String operation = 'Request',
  }) {
    final message =
        messageFromBody(body) ?? _statusMessage(statusCode, operation);
    return statusCode == 401 || statusCode == 403
        ? AuthenticationException(message)
        : AppException(message);
  }

  static AppException connection(Object error, {String operation = 'Request'}) {
    if (error is AppException) return error;
    if (error is TimeoutException) {
      return AppException(
        '$operation timed out. Check your connection and try again.',
        error,
      );
    }
    if (error is SocketException || error is http.ClientException) {
      return AppException(
        '$operation could not reach the server. Check your internet connection and server address.',
        error,
      );
    }
    return AppException('$operation failed. Please try again.', error);
  }

  static String? messageFromBody(String source) {
    try {
      final root = (jsonDecode(source) as Map).cast<String, dynamic>();
      final payload = root['message'] is Map
          ? (root['message'] as Map).cast<String, dynamic>()
          : root;
      final direct =
          payload['message'] ?? payload['error'] ?? root['exception'];
      final normalized = _clean(direct);
      return normalized ?? _frappeMessages(root['_server_messages']);
    } catch (_) {
      return null;
    }
  }

  static String _statusMessage(int code, String operation) {
    if (code == 400 || code == 417 || code == 422) {
      return '$operation was rejected because the submitted data is invalid.';
    }
    if (code == 401) {
      return 'Your session is invalid. Sign in again.';
    }
    if (code == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (code == 404) {
      return '$operation API was not found on the server. Update the Frappe app.';
    }
    if (code == 408) {
      return '$operation timed out. Please try again.';
    }
    if (code == 409) {
      return '$operation conflicts with an existing record.';
    }
    if (code == 429) {
      return 'Too many requests. Wait a moment and try again.';
    }
    if (code >= 500) {
      return 'The server could not complete $operation. Please try again later.';
    }
    return '$operation failed (HTTP $code).';
  }

  static String? _frappeMessages(Object? raw) {
    if (raw == null) return null;
    try {
      final values = raw is String ? jsonDecode(raw) : raw;
      if (values is! List) return _clean(values);
      final messages = <String>[];
      for (final value in values) {
        final decoded = value is String ? _tryDecode(value) : value;
        final cleaned = _clean(decoded is Map ? decoded['message'] : decoded);
        if (cleaned != null && !messages.contains(cleaned)) {
          messages.add(cleaned);
        }
      }
      return messages.isEmpty ? null : messages.join('\n');
    } catch (_) {
      return _clean(raw);
    }
  }

  static Object? _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  static String? _clean(Object? value) {
    if (value == null || value is Map || value is List) return null;
    final result = '$value'
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\\n|[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return result.isEmpty ? null : result;
  }
}
