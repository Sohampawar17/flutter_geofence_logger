import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/api_logger.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/utils/validators.dart';

class EmployeeSession {
  final String baseUrl, apiKey, apiSecret, employeeName, employeeId;
  final String designation, dateOfJoining, dateOfBirth, gender;
  final String companyEmail, personalEmail, cellNumber;
  final String emergencyPhoneNumber, employeeImage;

  const EmployeeSession({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    required this.employeeName,
    required this.employeeId,
    this.designation = '',
    this.dateOfJoining = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.companyEmail = '',
    this.personalEmail = '',
    this.cellNumber = '',
    this.emergencyPhoneNumber = '',
    this.employeeImage = '',
  });

  bool get authenticated =>
      baseUrl.isNotEmpty &&
      apiKey.isNotEmpty &&
      apiSecret.isNotEmpty &&
      employeeId.isNotEmpty;

  Map<String, String> toMap() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'apiSecret': apiSecret,
    'employeeName': employeeName,
    'employeeId': employeeId,
    'designation': designation,
    'dateOfJoining': dateOfJoining,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'companyEmail': companyEmail,
    'personalEmail': personalEmail,
    'cellNumber': cellNumber,
    'emergencyPhoneNumber': emergencyPhoneNumber,
    'employeeImage': employeeImage,
  };
}

class EmployeeAuthService {
  static const _channel = MethodChannel(
    'com.geopulse.geofence_logger/background',
  );
  static const _apiPath = '/api/method/geofence_logger.mobile.app';
  final http.Client client;

  EmployeeAuthService({http.Client? client}) : client = client ?? http.Client();

  Future<EmployeeSession> read() async {
    final value =
        await _channel.invokeMapMethod<String, String>('readEmployeeSession') ??
        const {};
    return _fromStored(value);
  }

  Future<EmployeeSession> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final base = Validators.httpsBaseUrl(baseUrl);
    final uri = Uri.parse('$base$_apiPath.login');
    final timer = Stopwatch()..start();
    ApiLogger.request('POST', uri, details: 'credentials=<redacted>');
    late http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'usr': username.trim(), 'pwd': password}),
          )
          .timeout(const Duration(seconds: 20));
      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        response.body,
        timer.elapsed,
      );
    } catch (error, stackTrace) {
      ApiLogger.error('POST', uri, error, stackTrace, timer.elapsed);
      throw ApiError.connection(error, operation: 'Sign in');
    }
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: 'Sign in',
      );
    }
    final payload = _payload(body);
    final keys = (payload['key_details'] as Map?)?.cast<String, dynamic>();
    final apiKey = '${keys?['api_key'] ?? ''}';
    final apiSecret = '${keys?['api_secret'] ?? ''}';
    final employeeId = '${payload['employee_id'] ?? ''}';
    if (apiKey.isEmpty || apiSecret.isEmpty || employeeId.isEmpty) {
      throw const AuthenticationException(
        'The server did not return employee API credentials.',
      );
    }

    final profile = await _getProfile(base, apiKey, apiSecret);
    final session = EmployeeSession(
      baseUrl: base,
      apiKey: apiKey,
      apiSecret: apiSecret,
      employeeName: '${profile['employee_name'] ?? payload['user'] ?? ''}',
      employeeId: '${profile['name'] ?? employeeId}',
      designation: '${profile['designation'] ?? ''}',
      dateOfJoining: '${profile['date_of_joining'] ?? ''}',
      dateOfBirth: '${profile['date_of_birth'] ?? ''}',
      gender: '${profile['gender'] ?? ''}',
      companyEmail: '${profile['company_email'] ?? ''}',
      personalEmail: '${profile['personal_email'] ?? ''}',
      cellNumber: '${profile['cell_number'] ?? ''}',
      emergencyPhoneNumber: '${profile['emergency_phone_number'] ?? ''}',
      employeeImage: '${profile['employee_image'] ?? ''}',
    );
    await _channel.invokeMethod('writeEmployeeSession', session.toMap());
    return session;
  }

  Future<Map<String, dynamic>> _getProfile(
    String base,
    String apiKey,
    String apiSecret,
  ) async {
    final uri = Uri.parse('$base$_apiPath.get_profile');
    final timer = Stopwatch()..start();
    ApiLogger.request('GET', uri);
    late http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: {
              'Authorization': 'token $apiKey:$apiSecret',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      ApiLogger.response(
        'GET',
        uri,
        response.statusCode,
        response.body,
        timer.elapsed,
      );
    } catch (error, stackTrace) {
      ApiLogger.error('GET', uri, error, stackTrace, timer.elapsed);
      throw ApiError.connection(error, operation: 'Profile loading');
    }
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError.response(
        response.statusCode,
        response.body,
        operation: 'Profile loading',
      );
    }
    return (_payload(body)['data'] as Map?)?.cast<String, dynamic>() ??
        const {};
  }

  Map<String, dynamic> _decode(String source) {
    try {
      return (jsonDecode(source) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  Map<String, dynamic> _payload(Map<String, dynamic> body) =>
      body['message'] is Map
      ? (body['message'] as Map).cast<String, dynamic>()
      : body;

  EmployeeSession _fromStored(Map<String, String> v) => EmployeeSession(
    baseUrl: v['baseUrl'] ?? '',
    apiKey: v['apiKey'] ?? '',
    apiSecret: v['apiSecret'] ?? '',
    employeeName: v['employeeName'] ?? '',
    employeeId: v['employeeId'] ?? '',
    designation: v['designation'] ?? '',
    dateOfJoining: v['dateOfJoining'] ?? '',
    dateOfBirth: v['dateOfBirth'] ?? '',
    gender: v['gender'] ?? '',
    companyEmail: v['companyEmail'] ?? '',
    personalEmail: v['personalEmail'] ?? '',
    cellNumber: v['cellNumber'] ?? '',
    emergencyPhoneNumber: v['emergencyPhoneNumber'] ?? '',
    employeeImage: v['employeeImage'] ?? '',
  );

  Future<void> logout() => _channel.invokeMethod('clearEmployeeSession');
}
