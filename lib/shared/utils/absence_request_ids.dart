import '../utils/attendance_policy.dart';

/// Deterministic identity for `absenceRequests` documents (W7 D-W7-5 / D-W7-8).
///
/// Same calendar-day encoding as [AttendancePolicy.legacyDocumentId], scoped by
/// halaqa + student so one pending request can exist per operated day.
/// (Attendance records themselves use session-scoped ids — see
/// [AttendancePolicy.documentId].)
class AbsenceRequestIds {
  const AbsenceRequestIds._();

  /// Format: `{halaqaId}_{studentId}_{yyyyMMdd}`
  static String documentId({
    required String halaqaId,
    required String studentId,
    required DateTime date,
  }) {
    return AttendancePolicy.legacyDocumentId(
      halaqaId: halaqaId,
      studentId: studentId,
      date: date,
    );
  }
}
