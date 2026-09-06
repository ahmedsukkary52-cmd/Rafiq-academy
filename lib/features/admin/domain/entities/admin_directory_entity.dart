import 'package:equatable/equatable.dart';

class AdminHalaqaSummaryEntity extends Equatable {
  final String id;
  final String name;
  final String teacherId;
  final String supervisorId;
  final int studentCount;

  const AdminHalaqaSummaryEntity({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.supervisorId,
    required this.studentCount,
  });

  @override
  List<Object?> get props => [id, name, teacherId, supervisorId, studentCount];
}

class AdminStaffSummaryEntity extends Equatable {
  final String uid;
  final String name;

  const AdminStaffSummaryEntity({required this.uid, required this.name});

  @override
  List<Object?> get props => [uid, name];
}
