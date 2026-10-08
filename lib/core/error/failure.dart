import 'package:equatable/equatable.dart';

import 'auth_error_reason.dart';

export 'auth_error_reason.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال بالإنترنت']);
}

class AuthFailure extends Failure {
  final AuthErrorReason reason;

  const AuthFailure(super.message, {this.reason = AuthErrorReason.generic});

  @override
  List<Object?> get props => [message, reason];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'حدث خطأ غير متوقع']);
}
