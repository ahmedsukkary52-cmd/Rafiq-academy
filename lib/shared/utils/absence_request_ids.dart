import '../utils/attendance_policy.dart';

/// Deterministic identity for `absenceRequests` documents (W7 D-W7-5 / D-W7-8).
///
/// Same calendar-day encoding as [AttendancePolicy.documentId], scoped by
/// halaqa + student so one pending request can exist per operated day.
class AbsenceRequestIds {
  const AbsenceRequestIds._();

  /// Format: `{halaqaId}_{studentId}_{yyyyMMdd}`
  static String documentId({
    required String halaqaId,
    required String studentId,
    required DateTime date,
  }) {
    final day = AttendancePolicy.dayStart(date);
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${halaqaId.trim()}_${studentId.trim()}_$y$m$d';
  }
}
