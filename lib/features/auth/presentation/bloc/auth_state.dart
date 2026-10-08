import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Logout failed; the session (and role routing) is still in effect.
class AuthLogoutFailure extends AuthAuthenticated {
  final String message;

  const AuthLogoutFailure(super.user, this.message);

  @override
  List<Object?> get props => [user, message];
}

/// Signed out. [message] explains a forced sign-out (disabled account,
/// missing profile, ended session) and is shown on the login page.
class AuthUnauthenticated extends AuthState {
  final String? message;

  const AuthUnauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

/// Login attempt failed; the user stays on the login page.
class AuthError extends AuthState {
  final String message;
  final AuthErrorReason reason;

  const AuthError(this.message, {this.reason = AuthErrorReason.generic});

  bool get isRetryable => reason == AuthErrorReason.network;

  @override
  List<Object?> get props => [message, reason];
}

/// Session restore could not reach Firebase; Splash offers a retry.
class AuthStartupFailure extends AuthState {
  final String message;

  const AuthStartupFailure(this.message);

  @override
  List<Object?> get props => [message];
}
