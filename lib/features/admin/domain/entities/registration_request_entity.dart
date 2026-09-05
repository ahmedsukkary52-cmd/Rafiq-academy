import 'package:equatable/equatable.dart';

/// Pending student eligibility (W8 Option A): registered student without halaqa.
class RegistrationRequestEntity extends Equatable {
  final String studentId;
  final String name;
  final String? phone;
  final String? email;
  final String? profileImageUrl;
  final DateTime? registeredAt;

  const RegistrationRequestEntity({
    required this.studentId,
    required this.name,
    this.phone,
    this.email,
    this.profileImageUrl,
    this.registeredAt,
  });

  @override
  List<Object?> get props => [
    studentId,
    name,
    phone,
    email,
    profileImageUrl,
    registeredAt,
  ];
}
