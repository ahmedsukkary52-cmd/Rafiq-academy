import '../../../../../shared/domain/absence_request.dart';

/// Presentation-only row for the Excuses history list (Phase 1 UI).
///
/// Not a domain entity. Phase 2 will map [AbsenceRequestEntity] → this shape.
class TeacherExcuseListItemData {
  final String id;
  final String title;
  final String dateLabel;
  final String reason;
  final AbsenceRequestStatus status;

  const TeacherExcuseListItemData({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.reason,
    required this.status,
  });
}
