import '../domain/academy_event.dart';
import 'attendance_policy.dart';

/// One saved attendance mark used to derive academy absence events.
class AttendanceMarkInput {
  final String studentId;
  final String studentName;
  final String halaqaId;
  final DateTime date;

  /// Raw Firestore status string (`present` / `absent` / `late`).
  final String status;

  const AttendanceMarkInput({
    required this.studentId,
    required this.studentName,
    required this.halaqaId,
    required this.date,
    required this.status,
  });
}

/// Pure projector: attendance status transitions → [AcademyEvent]s.
///
/// Does **not** use [AttendancePolicy.isAbsentStatus] (that treats unknown/null
/// as absent). Only the explicit wire value `absent` creates absence events.
class AttendanceAbsenceTransitions {
  const AttendanceAbsenceTransitions._();

  /// True only for the explicit absent wire value.
  static bool isExplicitAbsent(String? status) =>
      (status ?? '').trim() == AttendancePolicy.statusAbsent;

  /// Derive academy events from previous day marks vs the marks being saved.
  ///
  /// [previousStatusByStudentId] must use **raw** status strings from Firestore
  /// (not [AttendanceRecordModel], which maps unknown → absent).
  static List<AcademyEvent> project({
    required Map<String, String?> previousStatusByStudentId,
    required Iterable<AttendanceMarkInput> currentMarks,
  }) {
    final events = <AcademyEvent>[];

    for (final mark in currentMarks) {
      final studentId = mark.studentId.trim();
      if (studentId.isEmpty) continue;

      final previous = previousStatusByStudentId[studentId];
      final current = mark.status.trim();
      final prevAbsent = isExplicitAbsent(previous);
      final currAbsent = isExplicitAbsent(current);

      final day = AttendancePolicy.dayStart(mark.date);
      final attendanceDocumentId = AttendancePolicy.documentId(
        halaqaId: mark.halaqaId,
        studentId: studentId,
        date: day,
      );

      if (!prevAbsent && currAbsent) {
        events.add(
          StudentAbsentRecorded(
            studentId: studentId,
            studentName: mark.studentName,
            halaqaId: mark.halaqaId,
            date: day,
            attendanceDocumentId: attendanceDocumentId,
          ),
        );
        continue;
      }

      if (prevAbsent && !currAbsent) {
        // Only emit correction when landing on an attended status.
        if (current != AttendancePolicy.statusPresent &&
            current != AttendancePolicy.statusLate) {
          continue;
        }
        events.add(
          StudentAbsenceCorrected(
            studentId: studentId,
            studentName: mark.studentName,
            halaqaId: mark.halaqaId,
            date: day,
            attendanceDocumentId: attendanceDocumentId,
            correctedToStatus: current,
          ),
        );
      }
    }

    return events;
  }
}
