library;

import 'auth_error_reason.dart';

export 'auth_error_reason.dart';

class ServerException implements Exception {
  final String message;

  const ServerException(this.message);

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;

  const CacheException(this.message);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  final AuthErrorReason reason;

  const AuthException(this.message, {this.reason = AuthErrorReason.generic});

  @override
  String toString() => message;
}
