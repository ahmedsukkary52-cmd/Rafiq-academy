import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String name;
  final String role;
  final String? email;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;

  /// Server-set (`userPrivate`) for Admin-issued temporary passwords.
  final bool mustChangePassword;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.role,
    this.email,
    this.profileImageUrl,
    required this.isActive,
    required this.createdAt,
    this.mustChangePassword = false,
  });

  @override
  List<Object?> get props => [
    uid,
    name,
    role,
    email,
    profileImageUrl,
    isActive,
    createdAt,
    mustChangePassword,
  ];
}
