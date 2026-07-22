import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class LoginWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginWithEmailEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String role;

  const RegisterWithEmailEvent({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
  });

  @override
  List<Object?> get props => [email, password, name, phone, role];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}
