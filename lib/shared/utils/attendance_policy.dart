/// Single product rule for attendance aggregates (W2 D1) + session identity.
///
/// `late` counts as attended everywhere — Teacher analytics, Student progress,
/// and Parent weekly report must use this helper (no local duplicates).
///
/// `excused` is a first-class status: not attended, not absent for at-risk;
/// excluded from attendance-percent denominator.
class AttendancePolicy {
  const AttendancePolicy._();

  static const String statusPresent = 'present';
  static const String statusAbsent = 'absent';
  static const String statusLate = 'late';
  static const String statusExcused = 'excused';

  /// Statuses that count toward attendance percentage / attended sessions.
  static const Set<String> attendedStatuses = {statusPresent, statusLate};

  static bool isAttendedStatus(String? status) =>
      attendedStatuses.contains((status ?? '').trim());

  /// Explicit absent only — never treats unknown / excused as absent.
  static bool isAbsentStatus(String? status) =>
      (status ?? '').trim() == statusAbsent;

  static bool isExcusedStatus(String? status) =>
      (status ?? '').trim() == statusExcused;

  static int countAttended(Iterable<String?> statuses) =>
      statuses.where(isAttendedStatus).length;

  static int countAbsent(Iterable<String?> statuses) =>
      statuses.where(isAbsentStatus).length;

  /// [attended] / [total] × 100. Returns 0 when [total] is 0.
  static double attendancePercent({required int attended, required int total}) {
    if (total <= 0) return 0;
    return (attended / total) * 100;
  }

  /// Percent over non-excused marks (`excused` excluded from the denominator).
  static double attendancePercentFromStatuses(Iterable<String?> statuses) {
    final list = statuses.where((s) => !isExcusedStatus(s)).toList();
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

  /// Operational teaching-session id — same shape as evaluations / W3 agenda:
  /// `{halaqaId}_yyyyMMdd`.
  static String sessionIdForDay({
    required String halaqaId,
    required DateTime day,
  }) {
    final d = dayStart(day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dayNum = d.day.toString().padLeft(2, '0');
    return '${halaqaId.trim()}_$y$m$dayNum';
  }

  /// Deterministic doc id — Evaluation-parity session identity.
  /// Format: `{sessionId}_{studentId}`
  static String documentId({
    required String sessionId,
    required String studentId,
  }) {
    final sid = sessionId.trim();
    final student = studentId.trim();
    if (sid.isEmpty || student.isEmpty) {
      throw ArgumentError(
        'sessionId and studentId are required for attendance documentId',
      );
    }
    return '${sid}_$student';
  }

  /// Legacy W2 D8 id `{halaqaId}_{studentId}_{yyyyMMdd}` — retirement only.
  static String legacyDocumentId({
    required String halaqaId,
    required String studentId,
    required DateTime date,
  }) {
    final d = dayStart(date);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${halaqaId.trim()}_${studentId.trim()}_$y$m$day';
  }

  /// Resolves the preferred document id for a stored/legacy mark.
  static String preferredDocumentId({
    required String halaqaId,
    required String studentId,
    required DateTime date,
    String? sessionId,
  }) {
    final stored = sessionId?.trim() ?? '';
    final sid = stored.isNotEmpty
        ? stored
        : sessionIdForDay(halaqaId: halaqaId, day: date);
    return documentId(sessionId: sid, studentId: studentId);
  }

  /// Whether a stored row belongs to the operational [sessionId].
  ///
  /// Prefers stored `sessionId`; legacy rows fall back to date-derived id.
  static bool belongsToSession({
    required String? recordSessionId,
    required String recordHalaqaId,
    required DateTime recordDate,
    required String sessionId,
    required String halaqaId,
  }) {
    if (recordHalaqaId.trim() != halaqaId.trim()) return false;
    final stored = recordSessionId?.trim() ?? '';
    if (stored.isNotEmpty) return stored == sessionId.trim();
    return sessionIdForDay(halaqaId: recordHalaqaId, day: recordDate) ==
        sessionId.trim();
  }

  /// Register is editable until the operational session closes.
  ///
  /// When [sessionEndAt] is known (schedule), closed at/after that instant.
  /// Otherwise closed after the session calendar day ends (local midnight).
  /// Historical (past) sessions stay read-only.
  static bool canEditSession({
    required DateTime sessionDate,
    DateTime? sessionEndAt,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (sessionEndAt != null) {
      return clock.isBefore(sessionEndAt);
    }
    final n = dayStart(clock);
    final s = dayStart(sessionDate);
    return !n.isAfter(s);
  }

  /// Preferred mark for [studentId] on a session (deterministic id wins).
  static AttendanceMarkRef? findSessionMark({
    required Iterable<AttendanceMarkRef> marks,
    required String halaqaId,
    required String studentId,
    required DateTime sessionDate,
    String? sessionId,
  }) {
    final preferredId = preferredDocumentId(
      halaqaId: halaqaId,
      studentId: studentId,
      date: sessionDate,
      sessionId: sessionId,
    );
    AttendanceMarkRef? fallback;
    for (final mark in marks) {
      if (mark.halaqaId.trim() != halaqaId.trim()) continue;
      if (mark.studentId.trim() != studentId.trim()) continue;
      if (!belongsToSession(
        recordSessionId: mark.sessionId,
        recordHalaqaId: mark.halaqaId,
        recordDate: mark.date,
        sessionId: sessionId ??
            sessionIdForDay(halaqaId: halaqaId, day: sessionDate),
        halaqaId: halaqaId,
      )) {
        continue;
      }
      if (mark.id == preferredId) return mark;
      fallback ??= mark;
    }
    return fallback;
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

  /// One status per (halaqa, student, operational session).
  /// Deterministic session document ids win over legacy auto-id duplicates.
  ///
  /// W4 absence transitions use the same win rule via
  /// [AttendanceAbsenceTransitions.previousStatusByStudent] — keep aligned.
  static List<String?> uniqueDayStatuses(Iterable<AttendanceMarkRef> marks) {
    final byKey = <String, String?>{};
    for (final mark in marks) {
      final preferredId = preferredDocumentId(
        halaqaId: mark.halaqaId,
        studentId: mark.studentId,
        date: mark.date,
        sessionId: mark.sessionId,
      );
      final existing = byKey.containsKey(preferredId);
      if (!existing || mark.id == preferredId) {
        byKey[preferredId] = mark.status;
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

  /// Operational session id when known (null on legacy rows).
  final String? sessionId;

  const AttendanceMarkRef({
    required this.id,
    required this.halaqaId,
    required this.studentId,
    required this.date,
    required this.status,
    this.sessionId,
  });
}
