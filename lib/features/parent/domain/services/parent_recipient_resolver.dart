import '../../../../shared/utils/firestore_in_query.dart';

/// Pure helpers for parentProfiles reverse lookup (W4 Pre-Slice).
///
/// Firestore `arrayContainsAny` accepts at most 30 values per query —
/// same operand limit as [FirestoreInQuery.whereInLimit].
class ParentRecipientResolver {
  const ParentRecipientResolver._();

  /// Firestore `array-contains-any` operand limit.
  static const int arrayContainsAnyLimit = FirestoreInQuery.whereInLimit;

  /// Normalize and de-duplicate student IDs; drop blanks.
  static List<String> normalizeStudentIds(Iterable<String> studentIds) =>
      FirestoreInQuery.normalizeIds(studentIds);

  /// Split into chunks of [arrayContainsAnyLimit].
  static List<List<String>> chunkStudentIds(List<String> studentIds) =>
      FirestoreInQuery.chunkIds(
        studentIds,
        limit: arrayContainsAnyLimit,
      );

  /// Merge a parent profile into `studentId → parentIds`.
  ///
  /// Only students present in [requestedStudentIds] are recorded.
  static void mergeParentProfile({
    required Map<String, List<String>> into,
    required String parentId,
    required Iterable<String> childrenIds,
    required Set<String> requestedStudentIds,
  }) {
    final pid = parentId.trim();
    if (pid.isEmpty) return;

    for (final raw in childrenIds) {
      final studentId = raw.trim();
      if (studentId.isEmpty) continue;
      if (!requestedStudentIds.contains(studentId)) continue;
      final list = into.putIfAbsent(studentId, () => <String>[]);
      if (!list.contains(pid)) list.add(pid);
    }
  }
}
