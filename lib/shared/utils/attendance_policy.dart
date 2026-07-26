/// Single product rule for attendance aggregates (W2 D1).
///
/// `late` counts as attended everywhere — Teacher analytics, Student progress,
/// and Parent weekly report must use this helper (no local duplicates).
class AttendancePolicy {
  const AttendancePolicy._();

  static const String statusPresent = 'present';
  static const String statusAbsent = 'absent';
  static const String statusLate = 'late';

  /// Statuses that count toward attendance percentage / attended sessions.
  static const Set<String> attendedStatuses = {statusPresent, statusLate};

  static bool isAttendedStatus(String? status) =>
      attendedStatuses.contains((status ?? '').trim());

  static bool isAbsentStatus(String? status) => !isAttendedStatus(status);

  static int countAttended(Iterable<String?> statuses) =>
      statuses.where(isAttendedStatus).length;

  static int countAbsent(Iterable<String?> statuses) =>
      statuses.where(isAbsentStatus).length;

  /// [attended] / [total] × 100. Returns 0 when [total] is 0.
  static double attendancePercent({required int attended, required int total}) {
    if (total <= 0) return 0;
    return (attended / total) * 100;
  }

  static double attendancePercentFromStatuses(Iterable<String?> statuses) {
    final list = statuses.toList();
    return attendancePercent(attended: countAttended(list), total: list.length);
  }

  /// Calendar day at local midnight (W2 D7 — day-based, not slot-based).
  static DateTime dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime dayEndExclusive(DateTime date) =>
      dayStart(date).add(const Duration(days: 1));

  /// True when [a] and [b] fall on the same local calendar day.
  static bool isSameCalendarDay(DateTime a, DateTime b) =>
      dayStart(a) == dayStart(b);

  /// Deterministic doc id — no new fields (W2 D8).
  /// Format: `{halaqaId}_{studentId}_{yyyyMMdd}`
  static String documentId({
    required String halaqaId,
    required String studentId,
    required DateTime date,
  }) {
    final d = dayStart(date);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${halaqaId}_${studentId}_$y$m$day';
  }

  /// Whether every roster student has a day mark (W2 register-complete).
  ///
  /// Empty roster is vacuously complete — nothing to mark. Used by W3
  /// orchestration; do not re-encode this comparison elsewhere.
  static bool isRegisterComplete({
    required Iterable<String> rosterStudentIds,
    required Iterable<String> markedStudentIds,
  }) {
    final roster = rosterStudentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (roster.isEmpty) return true;
    final marked = markedStudentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return marked.containsAll(roster);
  }

  /// Inverse of [isRegisterComplete].
  static bool isRegisterIncomplete({
    required Iterable<String> rosterStudentIds,
    required Iterable<String> markedStudentIds,
  }) => !isRegisterComplete(
    rosterStudentIds: rosterStudentIds,
    markedStudentIds: markedStudentIds,
  );

  /// One status per (halaqa, student, calendar day).
  /// Deterministic document ids win over legacy auto-id duplicates.
  ///
  /// W4 absence transitions use the same win rule via
  /// [AttendanceAbsenceTransitions.previousStatusByStudent] — keep aligned.
  static List<String?> uniqueDayStatuses(Iterable<AttendanceMarkRef> marks) {
    final byKey = <String, String?>{};
    for (final mark in marks) {
      final day = dayStart(mark.date);
      final preferredId = documentId(
        halaqaId: mark.halaqaId,
        studentId: mark.studentId,
        date: day,
      );
      final key = preferredId;
      final existing = byKey.containsKey(key);
      if (!existing || mark.id == preferredId) {
        byKey[key] = mark.status;
      }
    }
    return byKey.values.toList();
  }
}

/// Minimal attendance mark identity for [AttendancePolicy.uniqueDayStatuses].
class AttendanceMarkRef {
  final String id;
  final String halaqaId;
  final String studentId;
  final DateTime date;
  final String? status;

  const AttendanceMarkRef({
    required this.id,
    required this.halaqaId,
    required this.studentId,
    required this.date,
    required this.status,
  });
}
