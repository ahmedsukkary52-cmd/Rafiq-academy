import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String name;
  final String role;
  final String phone;
  final String? email;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.role,
    required this.phone,
    this.email,
    this.profileImageUrl,
    required this.isActive,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    uid,
    name,
    role,
    phone,
    email,
    profileImageUrl,
    isActive,
    createdAt,
  ];
}
