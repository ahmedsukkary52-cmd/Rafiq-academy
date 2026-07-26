/// Pure helpers for parentProfiles reverse lookup (W4 Pre-Slice).
///
/// Firestore `arrayContainsAny` accepts at most 30 values per query.
class ParentRecipientResolver {
  const ParentRecipientResolver._();

  /// Firestore `array-contains-any` operand limit.
  static const int arrayContainsAnyLimit = 30;

  /// Normalize and de-duplicate student IDs; drop blanks.
  static List<String> normalizeStudentIds(Iterable<String> studentIds) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in studentIds) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    return out;
  }

  /// Split into chunks of [arrayContainsAnyLimit].
  static List<List<String>> chunkStudentIds(List<String> studentIds) {
    final normalized = normalizeStudentIds(studentIds);
    if (normalized.isEmpty) return const [];
    final chunks = <List<String>>[];
    for (var i = 0; i < normalized.length; i += arrayContainsAnyLimit) {
      final end = (i + arrayContainsAnyLimit < normalized.length)
          ? i + arrayContainsAnyLimit
          : normalized.length;
      chunks.add(normalized.sublist(i, end));
    }
    return chunks;
  }

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
