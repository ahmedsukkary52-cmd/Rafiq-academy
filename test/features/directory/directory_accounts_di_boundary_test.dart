import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/features/accounts/data/academy_accounts_repository.dart';
import 'package:rafiq_academy/features/directory/data/academy_directory_repository.dart';

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

  test('registerDirectoryAndAccountsRepositories is idempotent and DI-backed', () {
    sl.registerLazySingleton<FirebaseFirestore>(() => UnusedFirestore());
    sl.registerLazySingleton<FirebaseFunctions>(() => _UnusedFunctions());

    registerDirectoryAndAccountsRepositories();
    registerDirectoryAndAccountsRepositories();

    final directory = sl<AcademyDirectoryRepository>();
    final accounts = sl<AcademyAccountsRepository>();
    expect(directory, same(sl<AcademyDirectoryRepository>()));
    expect(accounts, same(sl<AcademyAccountsRepository>()));
    expect(directory, isA<FirestoreAcademyDirectoryRepository>());
  });

  test('directory/onboard presentation resolves repos via GetIt, not concrete ctor', () {
    final directoryPage = File(
      'lib/features/directory/presentation/admin_directory_page.dart',
    ).readAsStringSync();
    expect(directoryPage, contains('sl<AcademyDirectoryRepository>()'));
    expect(directoryPage, isNot(contains('FirestoreAcademyDirectoryRepository(')));
    expect(_codeUsesFirebaseInstance(directoryPage), isFalse);

    final onboard = File(
      'lib/features/accounts/presentation/admin_onboard_student_page.dart',
    ).readAsStringSync();
    expect(onboard, contains('sl<AcademyAccountsRepository>()'));
    expect(onboard, isNot(contains('AcademyAccountsRepository(')));
    expect(_codeUsesFirebaseInstance(onboard), isFalse);

    final firstLogin = File(
      'lib/features/auth/presentation/pages/first_login_page.dart',
    ).readAsStringSync();
    expect(firstLogin, contains('sl<AcademyAccountsRepository>()'));
    expect(firstLogin, isNot(contains('AcademyAccountsRepository(')));

    final accessCard = File(
      'lib/features/accounts/presentation/admin_account_access_card.dart',
    ).readAsStringSync();
    expect(accessCard, contains('sl<AcademyAccountsRepository>()'));
    expect(accessCard, isNot(contains('AcademyAccountsRepository(')));

    final container = File(
      'lib/core/di/injection_container.dart',
    ).readAsStringSync();
    expect(container, contains('registerDirectoryAndAccountsRepositories'));
    expect(container, contains('FirestoreAcademyDirectoryRepository('));
  });
}
