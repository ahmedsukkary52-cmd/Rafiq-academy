/// C7 / WA-9 — session conflict contract (server-authoritative).
///
/// Hard conflicts: same halaqa, same teacher, student roster intersection.
/// Supervisor overlap is allowed. Client checks are advisory only.
class SessionConflictContract {
  const SessionConflictContract._();

  static const String locksCollection = 'sessionConflictLocks';

  static const String reasonSameHalaqa = 'same_halaqa';
  static const String reasonSameTeacher = 'same_teacher';
  static const String reasonStudentRoster = 'student_roster_intersection';
  static const String reasonInvalidInterval = 'invalid_interval';

  /// Statuses that participate in the conflict set (C7 §7.2).
  static const Set<String> participantStatuses = {
    'scheduled',
    'in_progress',
  };

  /// Always excluded from conflict detection.
  static const Set<String> excludedStatuses = {
    'cancelled',
    'completed',
  };

  static bool participatesInConflicts(String? status) =>
      participantStatuses.contains((status ?? '').trim());
}
