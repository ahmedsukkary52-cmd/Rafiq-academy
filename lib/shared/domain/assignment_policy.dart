/// Single product rule for "current / latest" homework (W1 D7).
///
/// All live readers of [FirestoreCollections.assignments] that mean
/// "the student's (or halaqa's) current assignment" must use the same
/// ordering: latest [dueDateField] first, limit [latestLimit].
///
/// Do not re-encode `orderBy(dueDate, desc).limit(1)` ad hoc.
class AssignmentPolicy {
  const AssignmentPolicy._();

  /// Firestore field used as the "current homework" clock.
  static const String dueDateField = 'dueDate';

  static const String studentIdField = 'studentId';
  static const String halaqaIdField = 'halaqaId';

  /// One document — the latest by due date.
  static const int latestLimit = 1;
}
