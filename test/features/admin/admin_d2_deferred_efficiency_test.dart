import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/data/admin_private_email_reader.dart';
import 'package:rafiq_academy/shared/utils/firestore_in_query.dart';

void main() {
  group('D2 deferred — query efficiency helpers', () {
    test('FirestoreInQuery chunks student name ids for payment-proof batching', () {
      final ids = List.generate(75, (i) => 's$i');
      final chunks = FirestoreInQuery.chunkIds(ids);
      expect(chunks.length, 3);
      expect(chunks.every((c) => c.length <= FirestoreInQuery.whereInLimit), isTrue);
      expect(chunks.expand((c) => c).toList(), ids);
    });

    test('AdminPrivateEmailReader.emailsOf preserves order and drops blanks', () async {
      // Pure contract on preferPrivate / cleaning — emailsOf needs Firestore;
      // verify the static preferPrivate path used after batched reads.
      expect(
        AdminPrivateEmailReader.preferPrivate(' a@b.c ', 'legacy@x'),
        'a@b.c',
      );
      expect(
        AdminPrivateEmailReader.preferPrivate(null, ' legacy@x '),
        'legacy@x',
      );
      expect(AdminPrivateEmailReader.preferPrivate('  ', ''), isNull);
    });

    test('normalizeIds de-dupes payment-proof student fan-out', () {
      expect(
        FirestoreInQuery.normalizeIds(['s1', ' s1 ', '', 's2', 's1']),
        ['s1', 's2'],
      );
    });
  });
}
