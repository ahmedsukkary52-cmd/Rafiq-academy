import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/features/admin/data/admin_reports_repository.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_reports_page.dart';

import '../../support/fake_callables.dart';

bool _codeUsesFirebaseInstance(String source) {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (trimmed.contains('FirebaseFirestore.instance')) return true;
  }
  return false;
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  test('registerAdminReportsRepository is idempotent and DI-backed', () {
    sl.registerLazySingleton<FirebaseFirestore>(() => UnusedFirestore());

    registerAdminReportsRepository();
    registerAdminReportsRepository();

    final repo = sl<AdminReportsRepository>();
    expect(defaultAdminReportsRepository(), same(repo));
  });

  test('admin reports page resolves repository via GetIt, not concrete ctor', () {
    final page = File(
      'lib/features/admin/presentation/pages/admin_reports_page.dart',
    ).readAsStringSync();
    expect(page, contains('defaultAdminReportsRepository()'));
    expect(page, contains('sl<AdminReportsRepository>()'));
    expect(page, isNot(contains('AdminReportsRepository(firestore')));
    expect(page, isNot(contains('package:cloud_firestore')));
    expect(_codeUsesFirebaseInstance(page), isFalse);

    final container = File('lib/core/di/injection_container.dart').readAsStringSync();
    expect(container, contains('registerAdminReportsRepository'));
    expect(container, contains('AdminReportsRepository(firestore'));
  });
}
