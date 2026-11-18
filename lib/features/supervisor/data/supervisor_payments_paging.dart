import '../../../shared/domain/parent_payment_proof.dart';
import '../../../shared/domain/payment_entity.dart';

/// D2 paging contract for supervisor per-student payment history.
///
/// **Why not `orderBy('dueDate')`:** Firestore excludes documents that lack the
/// ordered field. Pre-D2 used an unordered `.get()`, so invoices without
/// `dueDate` (legacy / conflict paths documented in BILLING_PAYMENT_CONTRACT)
/// still appeared. Ordering by document id keeps that completeness property
/// while bounding peak reads per page.
///
/// **Display order** remains a client sort after the full walk: proof-pending
/// first, then `dueDate` descending (same comparator as pre-D2).
class SupervisorPaymentsPaging {
  static const int pageSize = 40;
  static const int concurrency = 8;

  /// Product display order — identical to the pre-D2 client sort.
  static int compareDisplayOrder(PaymentEntity a, PaymentEntity b) {
    final aPending = a.hasProofAwaitingReview ? 0 : 1;
    final bPending = b.hasProofAwaitingReview ? 0 : 1;
    if (aPending != bPending) return aPending.compareTo(bPending);
    return b.dueDate.compareTo(a.dueDate);
  }

  /// Accumulates document-id-ordered pages until a short page.
  /// Later pages overwrite earlier ids (dedupe); short page ends the walk.
  static Map<String, T> accumulateIdOrderedPages<T>({
    required Iterable<List<T>> pages,
    required String Function(T item) idOf,
    int pageSize = SupervisorPaymentsPaging.pageSize,
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

  /// Chunks student ids for bounded concurrency (same coverage as a serial loop).
  static List<List<String>> concurrencyChunks(
    List<String> studentIds, {
    int concurrency = SupervisorPaymentsPaging.concurrency,
  }) {
    if (concurrency <= 0) {
      throw ArgumentError.value(concurrency, 'concurrency');
    }
    final chunks = <List<String>>[];
    for (var i = 0; i < studentIds.length; i += concurrency) {
      final end = (i + concurrency < studentIds.length)
          ? i + concurrency
          : studentIds.length;
      chunks.add(studentIds.sublist(i, end));
    }
    return chunks;
  }

  /// Firestore `permission-denied` on one student must not abort the others.
  static bool swallowPermissionDenied(String code) => code == 'permission-denied';
}
