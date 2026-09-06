import '../../../../../shared/domain/absence_request.dart';

/// Presentation row for Teacher Excuses / استئذان review list.
class TeacherExcuseListItemData {
  final String id;
  final String title;
  final String dateLabel;
  final String reason;
  final AbsenceRequestStatus status;
  final String? studentId;
  final String? halaqaId;
  final String? subtitle;

  const TeacherExcuseListItemData({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.reason,
    required this.status,
    this.studentId,
    this.halaqaId,
    this.subtitle,
  });
}
