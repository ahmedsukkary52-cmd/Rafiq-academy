import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/supervisor/data/supervisor_payments_paging.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/shared/domain/payment_entity.dart';

/// Simulates one Firestore payment doc for a student. [hasDueDateField] false
/// models a legacy/conflict invoice that the old unordered `.get()` returned
/// but `orderBy('dueDate')` would drop.
class _RawPaymentDoc {
  const _RawPaymentDoc({
    required this.id,
    required this.hasDueDateField,
    this.dueDate,
    this.pendingProof = false,
  });

  final String id;
  final bool hasDueDateField;
  final DateTime? dueDate;
  final bool pendingProof;
}

PaymentEntity _toEntity(_RawPaymentDoc d, {required DateTime missingDueFallback}) {
  return PaymentEntity(
    id: d.id,
    studentId: 's1',
    parentId: 'p1',
    amount: 100,
    // Mirrors PaymentModel.fromFirestore: missing/invalid → fallback DateTime.
    dueDate: d.hasDueDateField ? (d.dueDate ?? missingDueFallback) : missingDueFallback,
    status: PaymentStatus.due,
    proofStoragePath: d.pendingProof ? 'proofs/x.png' : null,
    proofSubmittedAt: d.pendingProof ? DateTime(2026, 1, 1) : null,
    reviewStatus: d.pendingProof
        ? ParentPaymentProofContract.pendingReview
        : null,
  );
}

/// documentId-ordered pages (ascending id), including docs without dueDate.
List<List<_RawPaymentDoc>> _idOrderedPages(
  List<_RawPaymentDoc> store, {
  required int pageSize,
}) {
  final sorted = [...store]..sort((a, b) => a.id.compareTo(b.id));
  final pages = <List<_RawPaymentDoc>>[];
  for (var i = 0; i < sorted.length; i += pageSize) {
    final end = (i + pageSize < sorted.length) ? i + pageSize : sorted.length;
    pages.add(sorted.sublist(i, end));
  }
  if (pages.isEmpty) pages.add(const []);
  return pages;
}

/// Contrasting walk: orderBy(dueDate) drops docs without the field.
List<_RawPaymentDoc> _dueDateOrderedOnly(List<_RawPaymentDoc> store) {
  return store.where((d) => d.hasDueDateField).toList()
    ..sort((a, b) => b.dueDate!.compareTo(a.dueDate!));
}

void main() {
  final fallback = DateTime(1970);

  group('document-id paging preserves missing dueDate', () {
    test('multi-page walk returns docs with and without dueDate; no gaps/dupes',
        () {
      const pageSize = 40;
      final store = <_RawPaymentDoc>[
        for (var i = 0; i < 95; i++)
          _RawPaymentDoc(
            id: 'p${i.toString().padLeft(3, '0')}',
            hasDueDateField: i % 5 != 0, // every 5th lacks dueDate
            dueDate: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      expect(store.where((d) => !d.hasDueDateField), hasLength(19));

      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1), reason: 'must exercise >1 page');

      final byId = SupervisorPaymentsPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );

      expect(byId.length, 95);
      expect(byId.keys.toSet(), store.map((d) => d.id).toSet());
      expect(
        byId.values.where((d) => !d.hasDueDateField).length,
        19,
        reason: 'missing-dueDate docs must survive the walk',
      );

      // Contrast: dueDate orderBy would silently drop them.
      expect(_dueDateOrderedOnly(store), hasLength(95 - 19));
    });

    test('docs with equal dueDate all appear across page boundaries', () {
      const pageSize = 10;
      final tie = DateTime(2026, 6, 15);
      final store = <_RawPaymentDoc>[
        for (var i = 0; i < 25; i++)
          _RawPaymentDoc(
            id: 't${i.toString().padLeft(2, '0')}',
            hasDueDateField: true,
            dueDate: tie, // all equal
          ),
        const _RawPaymentDoc(id: 'z_missing', hasDueDateField: false),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1));

      final byId = SupervisorPaymentsPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      expect(byId.length, 26);
      expect(byId.containsKey('z_missing'), isTrue);
      expect(
        byId.values.where((d) => d.hasDueDateField && d.dueDate == tie).length,
        25,
      );
    });

    test('walk stops after short page and does not invent rows', () {
      const pageSize = 40;
      final store = [
        for (var i = 0; i < 12; i++)
          _RawPaymentDoc(
            id: 's$i',
            hasDueDateField: i.isEven,
            dueDate: DateTime(2026, 2, i + 1),
          ),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages, hasLength(1));
      expect(pages.single, hasLength(12));

      final byId = SupervisorPaymentsPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      expect(byId.length, 12);
      expect(byId.values.where((d) => !d.hasDueDateField).length, 6);
    });
  });

  group('display order (proof-pending then dueDate desc)', () {
    test('pending proof ranks above older due dates; missing dueDate kept', () {
      final list = [
        _toEntity(
          _RawPaymentDoc(
            id: 'old',
            hasDueDateField: true,
            dueDate: DateTime(2025, 1, 1),
          ),
          missingDueFallback: fallback,
        ),
        _toEntity(
          _RawPaymentDoc(
            id: 'pending',
            hasDueDateField: true,
            dueDate: DateTime(2024, 1, 1),
            pendingProof: true,
          ),
          missingDueFallback: fallback,
        ),
        _toEntity(
          const _RawPaymentDoc(id: 'no_due', hasDueDateField: false),
          missingDueFallback: fallback,
        ),
        _toEntity(
          _RawPaymentDoc(
            id: 'new',
            hasDueDateField: true,
            dueDate: DateTime(2026, 12, 1),
          ),
          missingDueFallback: fallback,
        ),
      ]..sort(SupervisorPaymentsPaging.compareDisplayOrder);

      expect(list.first.id, 'pending');
      expect(list.first.hasProofAwaitingReview, isTrue);
      expect(list.map((e) => e.id).toSet(), {'old', 'pending', 'no_due', 'new'});
      final nonPending = list.skip(1).toList();
      for (var i = 1; i < nonPending.length; i++) {
        expect(
          nonPending[i - 1].dueDate.compareTo(nonPending[i].dueDate) >= 0,
          isTrue,
        );
      }
    });
  });

  group('permission-denied and concurrency', () {
    test('permission-denied is swallowed; other codes are not', () {
      expect(
        SupervisorPaymentsPaging.swallowPermissionDenied('permission-denied'),
        isTrue,
      );
      expect(
        SupervisorPaymentsPaging.swallowPermissionDenied('unavailable'),
        isFalse,
      );
    });

    test('one denied student does not drop another student\'s pages', () {
      const pageSize = 5;
      final okStore = [
        for (var i = 0; i < 12; i++)
          _RawPaymentDoc(
            id: 'ok$i',
            hasDueDateField: i != 3,
            dueDate: DateTime(2026, 3, i + 1),
          ),
      ];
      final byId = <String, _RawPaymentDoc>{};

      // student A: permission-denied → skip
      final denied = 'permission-denied';
      expect(SupervisorPaymentsPaging.swallowPermissionDenied(denied), isTrue);

      // student B: multi-page accumulate
      final pages = _idOrderedPages(okStore, pageSize: pageSize);
      expect(pages.length, greaterThan(1));
      byId.addAll(
        SupervisorPaymentsPaging.accumulateIdOrderedPages(
          pages: pages,
          idOf: (d) => d.id,
          pageSize: pageSize,
        ),
      );

      expect(byId.length, 12);
      expect(byId.values.where((d) => !d.hasDueDateField), hasLength(1));
    });

    test('concurrency chunks cover every student id', () {
      final ids = List.generate(23, (i) => 's$i');
      final chunks = SupervisorPaymentsPaging.concurrencyChunks(ids);
      expect(chunks.expand((c) => c).toList(), ids);
      expect(chunks.first, hasLength(8));
      expect(chunks.last, hasLength(7));
    });
  });

  group('history exhaust', () {
    test('after short page further accumulate does not run past exhaust', () {
      const pageSize = 40;
      final store = [
        for (var i = 0; i < 95; i++)
          _RawPaymentDoc(
            id: 'h${i.toString().padLeft(3, '0')}',
            hasDueDateField: true,
            dueDate: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
        const _RawPaymentDoc(id: 'h_missing_a', hasDueDateField: false),
        const _RawPaymentDoc(id: 'h_missing_b', hasDueDateField: false),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1));
      expect(pages.last.length, lessThan(pageSize));

      final byId = SupervisorPaymentsPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      expect(byId.length, store.length);
      expect(byId.containsKey('h_missing_a'), isTrue);
      expect(byId.containsKey('h_missing_b'), isTrue);
    });
  });
}
