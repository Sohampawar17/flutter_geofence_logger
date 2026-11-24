class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.cause]);
}
