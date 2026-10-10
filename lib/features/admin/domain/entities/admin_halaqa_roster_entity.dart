import 'package:equatable/equatable.dart';

class AdminRosterStudentEntity extends Equatable {
  final String uid;
  final String name;
  final String? phone;
  final String? profileImageUrl;
  final bool isActive;

  const AdminRosterStudentEntity({
    required this.uid,
    required this.name,
    this.phone,
    this.profileImageUrl,
    required this.isActive,
  });

  @override
  List<Object?> get props => [uid, name, phone, profileImageUrl, isActive];
}

class AdminHalaqaRosterEntity extends Equatable {
  final String id;
  final String name;
  final String teacherId;
  final String supervisorId;
  final String status;
  final List<AdminRosterStudentEntity> students;

  const AdminHalaqaRosterEntity({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.supervisorId,
    required this.status,
    required this.students,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    teacherId,
    supervisorId,
    status,
    students,
  ];
}
