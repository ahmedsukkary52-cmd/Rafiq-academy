import 'assignment_kind.dart';

/// Single product rule for "current / latest" homework (W1 D7).
///
/// All live readers of [FirestoreCollections.assignments] that mean
/// "the student's (or halaqa's) current assignment" must use the same
/// ordering: latest [dueDateField] first, then pick the first
/// [AssignmentKind.lessonHomework] document (legacy docs without `kind`
/// count as lesson homework).
///
/// Do not re-encode ad hoc latest queries.
class AssignmentPolicy {
  const AssignmentPolicy._();

  /// Firestore field used as the "current homework" clock.
  static const String dueDateField = 'dueDate';

  static const String studentIdField = 'studentId';
  static const String halaqaIdField = 'halaqaId';
  static const String kindField = 'kind';
  static const String createdAtField = 'createdAt';

  /// Scan window when filtering out [AssignmentKind.halaqaActivity].
  ///
  /// Wider than [latestLimit] so a newly published activity cannot hide the
  /// real lesson homework when both share the same collection ordering.
  static const int latestScanLimit = 20;

  /// One lesson-homework document after kind filtering.
  static const int latestLimit = 1;

  static bool isLessonHomeworkData(Map<String, dynamic>? data) {
    if (data == null) return true;
    return AssignmentKind.isLessonHomeworkWire(data[kindField]);
  }

  static bool isHalaqaActivityData(Map<String, dynamic>? data) {
    if (data == null) return false;
    return AssignmentKind.isHalaqaActivityWire(data[kindField]);
  }
}
