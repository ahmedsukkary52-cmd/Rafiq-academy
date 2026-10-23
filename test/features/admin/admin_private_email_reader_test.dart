import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/data/admin_private_email_reader.dart';

import '../auth/auth_fakes.dart';

void main() {
  group('AdminPrivateEmailReader.emailOf', () {
    test('reads the trimmed email from userPrivate/{uid}', () async {
      final store = FakeFirestore({
        'userPrivate/u1': {
          'email': '  u1@example.test ',
          'emailSource': 'auth',
        },
      });
      expect(
        await AdminPrivateEmailReader(store).emailOf('u1'),
        'u1@example.test',
      );
    });

    test('missing document or blank uid gives null', () async {
      final reader = AdminPrivateEmailReader(FakeFirestore());
      expect(await reader.emailOf('u1'), isNull);
      expect(await reader.emailOf('  '), isNull);
    });

    test('permission-denied (e.g. legacy phone doc) gives null', () async {
      final store = FakeFirestore({
        'userPrivate/u1': {'email': 'u1@example.test'},
      })..getErrorCode = 'permission-denied';
      expect(await AdminPrivateEmailReader(store).emailOf('u1'), isNull);
    });

    test('non-string or empty email gives null', () async {
      final store = FakeFirestore({
        'userPrivate/a': {'email': 42},
        'userPrivate/b': {'email': '   '},
        'userPrivate/c': {'other': 'x'},
      });
      final reader = AdminPrivateEmailReader(store);
      for (final uid in ['a', 'b', 'c']) {
        expect(await reader.emailOf(uid), isNull, reason: uid);
      }
    });
  });

  group('AdminPrivateEmailReader.preferPrivate (transition order)', () {
    test('private email wins over the legacy users.email', () {
      expect(
        AdminPrivateEmailReader.preferPrivate('new@x.test', 'old@x.test'),
        'new@x.test',
      );
    });

    test('falls back to the legacy users.email until migrated', () {
      expect(
        AdminPrivateEmailReader.preferPrivate(null, ' old@x.test '),
        'old@x.test',
      );
      expect(
        AdminPrivateEmailReader.preferPrivate('  ', 'old@x.test'),
        'old@x.test',
      );
    });

    test('null when neither source has a usable email', () {
      expect(AdminPrivateEmailReader.preferPrivate(null, null), isNull);
      expect(AdminPrivateEmailReader.preferPrivate(null, 7), isNull);
    });
  });
}
