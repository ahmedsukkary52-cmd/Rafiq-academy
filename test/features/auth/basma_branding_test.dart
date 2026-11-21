import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/academy_branding.dart';

void main() {
  test('user-facing central branding uses Basma and excludes Rafiq', () {
    for (final value in [
      AcademyBranding.displayName,
      AcademyBranding.shortName,
      AcademyBranding.fullTitle,
    ]) {
      expect(value, isNot(contains('رفيق')));
      expect(value, contains('بصمة'));
    }
  });
}
