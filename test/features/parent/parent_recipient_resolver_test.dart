import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/services/parent_recipient_resolver.dart';

void main() {
  group('ParentRecipientResolver', () {
    test('normalize drops blanks and duplicates', () {
      expect(
        ParentRecipientResolver.normalizeStudentIds([
          ' s1 ',
          '',
          's1',
          's2',
          '  ',
        ]),
        ['s1', 's2'],
      );
    });

    test('chunk respects Firestore arrayContainsAny limit', () {
      final ids = List.generate(65, (i) => 's$i');
      final chunks = ParentRecipientResolver.chunkStudentIds(ids);
      expect(chunks, hasLength(3));
      expect(chunks[0], hasLength(30));
      expect(chunks[1], hasLength(30));
      expect(chunks[2], hasLength(5));
    });

    test('empty input → no chunks', () {
      expect(ParentRecipientResolver.chunkStudentIds(const []), isEmpty);
    });

    test('mergeParentProfile maps only requested children', () {
      final into = <String, List<String>>{};
      ParentRecipientResolver.mergeParentProfile(
        into: into,
        parentId: 'p1',
        childrenIds: const ['s1', 's2', 's9'],
        requestedStudentIds: {'s1', 's2'},
      );
      expect(into.keys.toSet(), {'s1', 's2'});
      expect(into['s1'], ['p1']);
      expect(into['s2'], ['p1']);
    });

    test('mergeParentProfile supports multiple parents per student', () {
      final into = <String, List<String>>{};
      ParentRecipientResolver.mergeParentProfile(
        into: into,
        parentId: 'p1',
        childrenIds: const ['s1'],
        requestedStudentIds: {'s1'},
      );
      ParentRecipientResolver.mergeParentProfile(
        into: into,
        parentId: 'p2',
        childrenIds: const ['s1'],
        requestedStudentIds: {'s1'},
      );
      expect(into['s1'], ['p1', 'p2']);
    });

    test('mergeParentProfile ignores blank parent id', () {
      final into = <String, List<String>>{};
      ParentRecipientResolver.mergeParentProfile(
        into: into,
        parentId: '  ',
        childrenIds: const ['s1'],
        requestedStudentIds: {'s1'},
      );
      expect(into, isEmpty);
    });
  });
}
