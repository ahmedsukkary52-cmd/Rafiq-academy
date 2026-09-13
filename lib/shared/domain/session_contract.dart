/// C6 / WA-8 — first-class `sessions/{sessionId}` contract.
///
/// Occurrence uniqueness: (halaqaId, slotId, Cairo date).
/// Materialization is server-owned (Cloud Function); clients must not invent
/// slotIds or overwrite frozen identity/snapshot fields.
class SessionContract {
  const SessionContract._();

  static const String collection = 'sessions';

  static const String halaqaIdField = 'halaqaId';
  static const String slotIdField = 'slotId';
  static const String dateField = 'date';
  static const String startAtField = 'startAt';
  static const String endAtField = 'endAt';
  static const String statusField = 'status';
  static const String teacherIdField = 'teacherId';
  static const String supervisorIdField = 'supervisorId';
  static const String createdAtField = 'createdAt';
  static const String updatedAtField = 'updatedAt';
  static const String createdByField = 'createdBy';

  /// C6 locked lifecycle values.
  static const String statusScheduled = 'scheduled';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const Set<String> statuses = {
    statusScheduled,
    statusInProgress,
    statusCompleted,
    statusCancelled,
  };

  static bool isValidStatus(String? status) =>
      statuses.contains((status ?? '').trim());

  /// Callable that materializes (create-or-reuse) a session occurrence.
  static const String materializeCallable = 'materializeSession';
}
