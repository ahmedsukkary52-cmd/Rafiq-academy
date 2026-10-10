import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/admin_broadcast_form.dart';

void main() {
  group('AdminBroadcastFormValidation', () {
    test('returns error when title empty', () {
      expect(
        AdminBroadcastFormValidation.error(
          title: '',
          body: 'body',
          targetRole: 'all',
        ),
        isNotNull,
      );
    });

    test('returns error when body empty', () {
      expect(
        AdminBroadcastFormValidation.error(
          title: 'title',
          body: '  ',
          targetRole: 'all',
        ),
        isNotNull,
      );
    });

    test('returns error for invalid target role', () {
      expect(
        AdminBroadcastFormValidation.error(
          title: 'title',
          body: 'body',
          targetRole: 'invalid',
        ),
        isNotNull,
      );
    });

    test('returns null for valid payload', () {
      expect(
        AdminBroadcastFormValidation.error(
          title: 'title',
          body: 'body',
          targetRole: 'all',
        ),
        isNull,
      );
    });
  });
}
