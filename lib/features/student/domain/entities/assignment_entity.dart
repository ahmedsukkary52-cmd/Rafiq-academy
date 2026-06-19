import 'package:equatable/equatable.dart';

class AssignmentEntity extends Equatable {
  final String id;
  final String studentId;
  final String assignedBy;
  final String newMemorizationRange;
  final String reviewRange;
  final DateTime dueDate;

  const AssignmentEntity({
    required this.id,
    required this.studentId,
    required this.assignedBy,
    required this.newMemorizationRange,
    required this.reviewRange,
    required this.dueDate,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    assignedBy,
    newMemorizationRange,
    reviewRange,
    dueDate,
  ];
}
