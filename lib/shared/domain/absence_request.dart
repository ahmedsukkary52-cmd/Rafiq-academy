import 'package:equatable/equatable.dart';

/// Shared استئذان request types (H4 / A-H6).
///
/// Domain ownership of the **request lifecycle** stays with W7 rules
/// (parent submit, teacher review). This module only homes the shared type
/// so teacher/supervisor readers do not import the parent feature package.
enum AbsenceRequestStatus { pending, approved, rejected }

class AbsenceRequestEntity extends Equatable {
  final String id;
  final String studentId;
  final String halaqaId;
  final String requestedBy;
  final DateTime date;
  final String reason;
  final AbsenceRequestStatus status;
  final String? reviewedBy;

  const AbsenceRequestEntity({
    required this.id,
    required this.studentId,
    required this.halaqaId,
    required this.requestedBy,
    required this.date,
    required this.reason,
    required this.status,
    this.reviewedBy,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    halaqaId,
    requestedBy,
    date,
    reason,
    status,
    reviewedBy,
  ];
}
