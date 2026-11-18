import '../../../shared/domain/recitation_record_entity.dart';

/// D2 paging contract for halaqa `recitationRecords`.
///
/// **Why not `orderBy('date')` alone:** Firestore excludes documents that lack
/// the ordered field. Current write paths set `date`, and the model defaults a
/// missing field to `DateTime.now()`, but live/legacy completeness is not
/// Cloud-proven. Cursor pages therefore order by document id (always present),
/// then apply the product date order client-side.
///
/// **maxRecords (fullHistory):** applied only after a full id-ordered walk +
/// date sort. Counts that need every pending row must use `maxRecords: null`.
///
/// **newestByDate:** separate bounded `orderBy(date)` path — not this helper's
/// walk loop; see [RecitationRecordsQueryMode.newestByDate].
class HalaqaRecitationPaging {
  static const int pageSize = 100;

  /// Newest-first by `date`, then id ascending for ties (deterministic).
  static int compareDateDesc(RecitationRecordEntity a, RecitationRecordEntity b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return a.id.compareTo(b.id);
  }

  /// Accumulates document-id-ordered pages until a short page.
  static Map<String, T> accumulateIdOrderedPages<T>({
    required Iterable<List<T>> pages,
    required String Function(T item) idOf,
    int pageSize = HalaqaRecitationPaging.pageSize,
  }) {
    final byId = <String, T>{};
    for (final page in pages) {
      for (final item in page) {
        byId[idOf(item)] = item;
      }
      if (page.length < pageSize) break;
    }
    return byId;
  }

  /// Sort newest-first then optionally truncate for display windows.
  static List<T> sortAndCap<T>({
    required Iterable<T> items,
    required int Function(T a, T b) compare,
    int? maxRecords,
  }) {
    final list = items.toList()..sort(compare);
    if (maxRecords == null) return list;
    if (maxRecords <= 0) return <T>[];
    if (list.length <= maxRecords) return list;
    return list.sublist(0, maxRecords);
  }
}
