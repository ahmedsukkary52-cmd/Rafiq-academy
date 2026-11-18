import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/data/halaqa_recitation_paging.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';

/// Simulates one Firestore recitation doc. [hasDateField] false models a legacy
/// row that `orderBy('date')` would drop but document-id paging must keep.
class _RawRecitationDoc {
  const _RawRecitationDoc({
    required this.id,
    required this.hasDateField,
    this.date,
    this.pending = false,
  });

  final String id;
  final bool hasDateField;
  final DateTime? date;
  final bool pending;
}

RecitationRecordEntity _entity(
  _RawRecitationDoc d, {
  required DateTime missingDateFallback,
}) {
  return RecitationRecordEntity(
    id: d.id,
    studentId: 's1',
    studentName: 'n',
    teacherId: 't1',
    halaqaId: 'h1',
    date: d.hasDateField ? (d.date ?? missingDateFallback) : missingDateFallback,
    type: RecitationType.memorization,
    versesRange: '',
    reviewStatus: d.pending ? 'pending' : 'reviewed',
  );
}

List<List<_RawRecitationDoc>> _idOrderedPages(
  List<_RawRecitationDoc> store, {
  required int pageSize,
}) {
  final sorted = [...store]..sort((a, b) => a.id.compareTo(b.id));
  final pages = <List<_RawRecitationDoc>>[];
  for (var i = 0; i < sorted.length; i += pageSize) {
    final end = (i + pageSize < sorted.length) ? i + pageSize : sorted.length;
    pages.add(sorted.sublist(i, end));
  }
  if (pages.isEmpty) pages.add(const []);
  return pages;
}

List<_RawRecitationDoc> _dateOrderedOnly(List<_RawRecitationDoc> store) =>
    store.where((d) => d.hasDateField).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));

void main() {
  final fallback = DateTime(1970);

  group('document-id paging preserves missing date', () {
    test('multi-page walk keeps docs with and without date; no gaps/dupes', () {
      const pageSize = HalaqaRecitationPaging.pageSize;
      final store = <_RawRecitationDoc>[
        for (var i = 0; i < 217; i++)
          _RawRecitationDoc(
            id: 'r${i.toString().padLeft(3, '0')}',
            hasDateField: i % 7 != 0,
            date: DateTime(2026, 1, 1).add(Duration(hours: i)),
            pending: i % 11 == 0,
          ),
      ];
      final missing = store.where((d) => !d.hasDateField).length;
      expect(missing, greaterThan(0));

      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1));

      final byId = HalaqaRecitationPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      expect(byId.length, 217);
      expect(byId.keys.toSet(), store.map((d) => d.id).toSet());
      expect(byId.values.where((d) => !d.hasDateField).length, missing);

      // Contrast: orderBy(date) would silently drop them.
      expect(_dateOrderedOnly(store).length, 217 - missing);
    });

    test('equal dates all appear; sort is deterministic by id', () {
      const pageSize = 10;
      final tie = DateTime(2026, 6, 15);
      final store = <_RawRecitationDoc>[
        for (var i = 0; i < 25; i++)
          _RawRecitationDoc(
            id: 't${i.toString().padLeft(2, '0')}',
            hasDateField: true,
            date: tie,
          ),
        const _RawRecitationDoc(id: 'z_missing', hasDateField: false),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1));
      final byId = HalaqaRecitationPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      expect(byId.length, 26);
      expect(byId.containsKey('z_missing'), isTrue);

      final sorted = HalaqaRecitationPaging.sortAndCap(
        items: byId.values.map((d) => _entity(d, missingDateFallback: fallback)),
        compare: HalaqaRecitationPaging.compareDateDesc,
      );
      final tieIds = sorted
          .where((e) => e.date == tie)
          .map((e) => e.id)
          .toList();
      expect(tieIds, [
        for (var i = 0; i < 25; i++) 't${i.toString().padLeft(2, '0')}',
      ]);
    });
  });

  group('maxRecords after full walk', () {
    test('cap applies only after date sort — not mid-walk by id order', () {
      const pageSize = 5;
      final store = <_RawRecitationDoc>[
        // Older id but newer date — must win newest-2 after full walk.
        _RawRecitationDoc(
          id: 'a01',
          hasDateField: true,
          date: DateTime(2026, 1, 1),
        ),
        _RawRecitationDoc(
          id: 'a02',
          hasDateField: true,
          date: DateTime(2026, 12, 1),
        ),
        _RawRecitationDoc(
          id: 'a03',
          hasDateField: true,
          date: DateTime(2026, 6, 1),
        ),
        const _RawRecitationDoc(id: 'a00_missing', hasDateField: false),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      final byId = HalaqaRecitationPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      final capped = HalaqaRecitationPaging.sortAndCap(
        items: byId.values.map((d) => _entity(d, missingDateFallback: fallback)),
        compare: HalaqaRecitationPaging.compareDateDesc,
        maxRecords: 2,
      );
      expect(capped.map((e) => e.id).toList(), ['a02', 'a03']);
    });

    test('null maxRecords retains every page including missing-date pending', () {
      const pageSize = 40;
      final store = <_RawRecitationDoc>[
        for (var i = 0; i < 120; i++)
          _RawRecitationDoc(
            id: 'p${i.toString().padLeft(3, '0')}',
            hasDateField: i != 5 && i != 105,
            date: DateTime(2025, 1, 1).add(Duration(days: i)),
            pending: i == 5 || i == 105 || i == 110,
          ),
      ];
      final pages = _idOrderedPages(store, pageSize: pageSize);
      expect(pages.length, greaterThan(1));
      final byId = HalaqaRecitationPaging.accumulateIdOrderedPages(
        pages: pages,
        idOf: (d) => d.id,
        pageSize: pageSize,
      );
      final all = HalaqaRecitationPaging.sortAndCap(
        items: byId.values.map((d) => _entity(d, missingDateFallback: fallback)),
        compare: HalaqaRecitationPaging.compareDateDesc,
      );
      expect(all, hasLength(120));
      expect(all.where((e) => e.isPendingReview).length, 3);
      expect(all.any((e) => e.id == 'p005'), isTrue);
      expect(all.any((e) => e.id == 'p105'), isTrue);
    });
  });

  group('newestByDate bounded window (display-only contract)', () {
    test('date-ordered limit excludes missing-date docs by design', () {
      final store = <_RawRecitationDoc>[
        for (var i = 0; i < 60; i++)
          _RawRecitationDoc(
            id: 'n${i.toString().padLeft(2, '0')}',
            hasDateField: i % 10 != 0,
            date: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
      ];
      // Emulates Firestore orderBy(date).limit(40): only docs with date field.
      final dated = _dateOrderedOnly(store);
      expect(dated.length, lessThan(60));
      final bounded = dated.take(40).toList();
      expect(bounded, hasLength(40));
      expect(bounded.every((d) => d.hasDateField), isTrue);
      expect(
        bounded.first.date!.isAfter(bounded.last.date!) ||
            bounded.first.date == bounded.last.date,
        isTrue,
      );
    });
  });
}
