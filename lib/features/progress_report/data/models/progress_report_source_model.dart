/// Raw attendance row from `attendanceRecords` (read-only).
class ProgressAttendanceDocModel {
  final String id;
  final DateTime date;
  final String status;

  const ProgressAttendanceDocModel({
    required this.id,
    required this.date,
    required this.status,
  });

  bool get isPresentLike => status == 'present' || status == 'late';

  bool get isAbsent => !isPresentLike;
}

/// Raw recitation row from `recitationRecords` (read-only).
class ProgressRecitationDocModel {
  final String id;
  final DateTime date;
  final String? notes;
  final String reviewStatus;

  const ProgressRecitationDocModel({
    required this.id,
    required this.date,
    required this.notes,
    required this.reviewStatus,
  });

  bool get isReviewed => reviewStatus != 'pending';
}

/// Firestore payloads for one progress-report load (no aggregates).
class ProgressReportSourceModel {
  final String studentId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<ProgressAttendanceDocModel> attendance;
  final List<ProgressRecitationDocModel> recitations;

  const ProgressReportSourceModel({
    required this.studentId,
    required this.rangeStart,
    required this.rangeEnd,
    required this.attendance,
    required this.recitations,
  });
}
