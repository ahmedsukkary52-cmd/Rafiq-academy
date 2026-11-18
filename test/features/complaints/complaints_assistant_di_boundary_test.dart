import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/features/assistant/data/cover_duty_repository.dart';
import 'package:rafiq_academy/features/assistant/presentation/assistant_home_page.dart';
import 'package:rafiq_academy/features/complaints/data/complaints_repository.dart';
import 'package:rafiq_academy/features/complaints/presentation/complaints_entry.dart';

import '../../support/fake_callables.dart';

class _UnusedFunctions extends Fake implements FirebaseFunctions {}

bool _codeUsesFirebaseInstance(String source) {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (trimmed.contains('FirebaseFirestore.instance')) return true;
    if (trimmed.contains('FirebaseFunctions.instance')) return true;
  }
  return false;
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  test('registerComplaintsAndAssistantRepositories is idempotent', () {
    sl.registerLazySingleton<FirebaseFirestore>(() => UnusedFirestore());
    sl.registerLazySingleton<FirebaseFunctions>(() => _UnusedFunctions());

    registerComplaintsAndAssistantRepositories();
    registerComplaintsAndAssistantRepositories();

    final complaints = sl<ComplaintsRepository>();
    final cover = sl<CoverDutyRepository>();
    expect(defaultComplaintsRepository(), same(complaints));
    expect(defaultCoverDutyRepository(), same(cover));
    expect(cover, isA<FirestoreCoverDutyRepository>());
  });

  test('complaints/assistant presentation resolves repos via GetIt', () {
    final entry = File(
      'lib/features/complaints/presentation/complaints_entry.dart',
    ).readAsStringSync();
    expect(entry, contains('sl<ComplaintsRepository>()'));
    expect(entry, isNot(contains('ComplaintsRepository(firestore')));
    expect(entry, isNot(contains('package:cloud_firestore')));
    expect(_codeUsesFirebaseInstance(entry), isFalse);

    final home = File(
      'lib/features/assistant/presentation/assistant_home_page.dart',
    ).readAsStringSync();
    expect(home, contains('sl<CoverDutyRepository>()'));
    expect(home, isNot(contains('FirestoreCoverDutyRepository(')));
    expect(home, isNot(contains('package:cloud_firestore')));
    expect(_codeUsesFirebaseInstance(home), isFalse);

    final banner = File(
      'lib/features/assistant/presentation/teacher_cover_banner.dart',
    ).readAsStringSync();
    expect(banner, contains('sl.isRegistered<CoverDutyRepository>()'));
    expect(banner, isNot(contains('sl.isRegistered<FirebaseFirestore>()')));
    expect(banner, isNot(contains('package:cloud_firestore')));

    final container = File('lib/core/di/injection_container.dart').readAsStringSync();
    expect(container, contains('registerComplaintsAndAssistantRepositories'));
  });
}
