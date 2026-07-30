/// Firestore `in` / `array-contains-any` operand limits (H5 / A-H10).
///
/// Use [chunkIds] before any `whereIn` / `arrayContainsAny` so rosters and
/// id lists larger than [whereInLimit] do not hard-fail.
class FirestoreInQuery {
  const FirestoreInQuery._();

  /// Firestore limit for `whereIn` and `array-contains-any` values.
  static const int whereInLimit = 30;

  /// Normalize and de-duplicate ids; drop blanks. Preserves first-seen order.
  static List<String> normalizeIds(Iterable<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    return out;
  }

  /// Split into chunks of at most [limit] (default [whereInLimit]).
  static List<List<String>> chunkIds(
    Iterable<String> ids, {
    int limit = whereInLimit,
  }) {
    assert(limit > 0, 'chunk limit must be positive');
    final normalized = normalizeIds(ids);
    if (normalized.isEmpty) return const [];
    final chunks = <List<String>>[];
    for (var i = 0; i < normalized.length; i += limit) {
      final end = (i + limit < normalized.length)
          ? i + limit
          : normalized.length;
      chunks.add(normalized.sublist(i, end));
    }
    return chunks;
  }
}
