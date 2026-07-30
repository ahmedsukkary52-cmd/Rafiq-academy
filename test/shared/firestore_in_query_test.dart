import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/services/parent_recipient_resolver.dart';
import 'package:rafiq_academy/shared/utils/firestore_in_query.dart';

void main() {
  group('FirestoreInQuery (H5 / A-H10 roster whereIn)', () {
    test('whereInLimit stays at Firestore max of 30', () {
      expect(FirestoreInQuery.whereInLimit, 30);
    });

    test('normalizeIds drops blanks and duplicates, keeps first-seen order', () {
      expect(
        FirestoreInQuery.normalizeIds(const [
          ' s1 ',
          '',
          's2',
          's1',
          '  ',
          's3',
        ]),
        ['s1', 's2', 's3'],
      );
    });

    test('chunkIds empty → no chunks', () {
      expect(FirestoreInQuery.chunkIds(const []), isEmpty);
      expect(FirestoreInQuery.chunkIds(const ['', '  ']), isEmpty);
    });

    test('chunkIds small roster stays a single whereIn batch', () {
      final ids = List.generate(30, (i) => 's$i');
      final chunks = FirestoreInQuery.chunkIds(ids);
      expect(chunks, hasLength(1));
      expect(chunks.single, hasLength(30));
    });

    test('chunkIds large roster splits without exceeding whereInLimit', () {
      final ids = List.generate(65, (i) => 's$i');
      final chunks = FirestoreInQuery.chunkIds(ids);
      expect(chunks, hasLength(3));
      expect(chunks[0], hasLength(30));
      expect(chunks[1], hasLength(30));
      expect(chunks[2], hasLength(5));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(FirestoreInQuery.whereInLimit));
      }
      expect(chunks.expand((c) => c).toList(), ids);
    });

    test('exactly 31 ids → two chunks (30 + 1)', () {
      final ids = List.generate(31, (i) => 's$i');
      final chunks = FirestoreInQuery.chunkIds(ids);
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(30));
      expect(chunks[1], hasLength(1));
    });
  });

  group('ParentRecipientResolver delegates to FirestoreInQuery', () {
    test('chunkStudentIds still respects 30 limit for large lists', () {
      final ids = List.generate(65, (i) => 's$i');
      final chunks = ParentRecipientResolver.chunkStudentIds(ids);
      expect(chunks, hasLength(3));
      expect(ParentRecipientResolver.arrayContainsAnyLimit, 30);
    });
  });
}
