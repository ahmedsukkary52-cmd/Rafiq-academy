import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/auth/domain/academy_login_identifier.dart';

void main() {
  test('usernames map to the internal .invalid login address', () {
    expect(
      AcademyLoginIdentifier.toAuthEmail(' ST123456 '),
      'st123456@members.rafiq-academy.invalid',
    );
    expect(AcademyLoginIdentifier.isUsername('pr000001'), isTrue);
  });

  test('emails pass through; anything else is rejected', () {
    expect(AcademyLoginIdentifier.toAuthEmail('a@x.test'), 'a@x.test');
    expect(AcademyLoginIdentifier.toAuthEmail('ab'), isNull);
    expect(AcademyLoginIdentifier.toAuthEmail('بريد خطأ'), isNull);
    expect(AcademyLoginIdentifier.toAuthEmail(''), isNull);
  });

  test('internal addresses are recognized for recovery routing', () {
    expect(
      AcademyLoginIdentifier.isInternalEmail(
        'st1@members.rafiq-academy.invalid',
      ),
      isTrue,
    );
    expect(AcademyLoginIdentifier.isInternalEmail('a@x.test'), isFalse);
    expect(AcademyLoginIdentifier.isInternalEmail(null), isFalse);
  });
}
