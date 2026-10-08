import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'student mushaf route enters MushafReaderHost directly (no surah 67)',
    () {
      final router = File('lib/core/router/router_app.dart').readAsStringSync();
      expect(router.contains('MushafReaderHost'), isTrue);
      expect(router.contains('MushafBlocScope'), isTrue);
      expect(router.contains('surahNumber = 67'), isFalse);
      expect(router.contains('surahNumber: 67'), isFalse);
    },
  );

  test('student home Mushaf tab uses reader host, not dashboard', () {
    final home = File(
      'lib/features/student/presentation/pages/student_home_page.dart',
    ).readAsStringSync();
    expect(home.contains('MushafReaderHost'), isTrue);
    expect(home.contains('StudentMushafDashboard'), isFalse);
  });
}
