import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/features/accounts/data/academy_accounts_repository.dart';
import 'package:rafiq_academy/features/chat/data/chat_groups_repository.dart';
import 'package:rafiq_academy/features/chat/presentation/chat_groups_provider.dart';

import '../../support/fake_callables.dart';

class _UnusedFunctions extends Fake implements FirebaseFunctions {}

class _UnusedStorage extends Fake implements FirebaseStorage {}

bool _codeUsesFirebaseInstance(String source) {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (trimmed.contains('FirebaseFirestore.instance')) return true;
    if (trimmed.contains('FirebaseFunctions.instance')) return true;
    if (trimmed.contains('FirebaseStorage.instance')) return true;
  }
  return false;
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  test('registerChatGroupsRepository is idempotent and DI-backed', () {
    sl.registerLazySingleton<FirebaseFirestore>(() => UnusedFirestore());
    sl.registerLazySingleton<FirebaseFunctions>(() => _UnusedFunctions());
    sl.registerLazySingleton<FirebaseStorage>(() => _UnusedStorage());

    registerChatGroupsRepository();
    registerChatGroupsRepository();

    final groups = sl<ChatGroupsRepository>();
    expect(groups, same(sl<ChatGroupsRepository>()));
    expect(resolveChatGroupsRepository(), same(groups));
    expect(groups.accounts, same(sl<AcademyAccountsRepository>()));
  });

  test('chat presentation resolves ChatGroupsRepository without Firebase clients', () {
    final provider = File(
      'lib/features/chat/presentation/chat_groups_provider.dart',
    ).readAsStringSync();
    expect(provider, contains('sl<ChatGroupsRepository>()'));
    expect(provider, isNot(contains('ChatGroupsRepository(firestore')));
    expect(provider, isNot(contains('sl<FirebaseStorage>()')));
    expect(provider, isNot(contains('sl<FirebaseFunctions>()')));
    expect(provider, isNot(contains('package:firebase_storage')));
    expect(provider, isNot(contains('package:cloud_functions')));
    expect(_codeUsesFirebaseInstance(provider), isFalse);

    final room = File(
      'lib/features/chat/presentation/pages/chat_room.dart',
    ).readAsStringSync();
    expect(room, contains('sl.isRegistered<ChatGroupsRepository>()'));
    expect(room, isNot(contains('sl.isRegistered<FirebaseStorage>()')));
    expect(room, isNot(contains('sl.isRegistered<FirebaseFunctions>()')));
    expect(_codeUsesFirebaseInstance(room), isFalse);

    final container = File('lib/core/di/injection_container.dart').readAsStringSync();
    expect(container, contains('registerChatGroupsRepository'));
    expect(container, contains('accounts: sl<AcademyAccountsRepository>()'));

    final groupsRepo = File(
      'lib/features/chat/data/chat_groups_repository.dart',
    ).readAsStringSync();
    expect(groupsRepo, contains('required this.accounts'));
    expect(groupsRepo, isNot(contains('final accounts = AcademyAccountsRepository')));
  });
}
