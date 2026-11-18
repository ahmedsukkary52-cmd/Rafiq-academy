import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/accounts/data/academy_accounts_repository.dart';

class _UnusedFunctions extends Fake implements FirebaseFunctions {}

/// Minimal in-memory Firestore for the linked-parents query shape.
class _Store extends Fake implements FirebaseFirestore {
  _Store(this.docs);

  /// path → data (null = missing doc).
  final Map<String, Map<String, dynamic>?> docs;
  Object? queryError;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.name);

  final _Store store;
  final String name;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(store, '$name/$path');

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query(store, name, field: field, arrayContains: arrayContains);
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(
    this.store,
    this.collection, {
    this.field,
    this.arrayContains,
    this.limitCount,
  });

  final _Store store;
  final String collection;
  final Object? field;
  final Object? arrayContains;
  final int? limitCount;

  @override
  Query<Map<String, dynamic>> limit(int limit) => _Query(
    store,
    collection,
    field: field,
    arrayContains: arrayContains,
    limitCount: limit,
  );

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (store.queryError != null) throw store.queryError!;
    final prefix = '$collection/';
    final matches = <_Snap>[];
    for (final entry in store.docs.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final data = entry.value;
      if (data == null) continue;
      if (field == 'childrenIds' && arrayContains != null) {
        final kids = data['childrenIds'];
        if (kids is! List || !kids.contains(arrayContains)) continue;
      }
      matches.add(_Snap(entry.key.split('/').last, data));
    }
    final limited =
        limitCount == null ? matches : matches.take(limitCount!).toList();
    return _QuerySnap(limited);
  }
}

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.store, this.path);

  final _Store store;
  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    return _DocSnap(id, store.docs[path]);
  }
}

// ignore: subtype_of_sealed_class
class _Snap extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snap(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic> data() => _data ?? const {};
}

// ignore: subtype_of_sealed_class
class _DocSnap extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _DocSnap(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class _QuerySnap extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnap(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

void main() {
  group('listLinkedParentsForStudent', () {
    test('maps linked parent profiles to MemberSearchHit with user names', () async {
      final store = _Store({
        'parentProfiles/p1': {
          'childrenIds': ['s1', 's2'],
        },
        'parentProfiles/p2': {
          'childrenIds': ['s1'],
        },
        'parentProfiles/other': {
          'childrenIds': ['sx'],
        },
        'users/p1': {'name': 'حسن'},
        'users/p2': {'name': 'نورة'},
      });
      final repo = AcademyAccountsRepository(
        functions: _UnusedFunctions(),
        firestore: store,
      );

      final hits = await repo.listLinkedParentsForStudent('s1');
      expect(hits.map((h) => h.uid), ['p1', 'p2']);
      expect(hits.map((h) => h.name), ['حسن', 'نورة']);
    });

    test('returns empty when no parents link the student', () async {
      final store = _Store({
        'parentProfiles/p1': {
          'childrenIds': ['other'],
        },
      });
      final repo = AcademyAccountsRepository(
        functions: _UnusedFunctions(),
        firestore: store,
      );
      expect(await repo.listLinkedParentsForStudent('s1'), isEmpty);
    });

    test('uses empty name when the users doc is missing', () async {
      final store = _Store({
        'parentProfiles/p1': {
          'childrenIds': ['s1'],
        },
        'users/p1': null,
      });
      final repo = AcademyAccountsRepository(
        functions: _UnusedFunctions(),
        firestore: store,
      );
      final hits = await repo.listLinkedParentsForStudent('s1');
      expect(hits.single.uid, 'p1');
      expect(hits.single.name, '');
    });

    test('honors the limit cap of three', () async {
      final docs = <String, Map<String, dynamic>?>{};
      for (var i = 1; i <= 5; i++) {
        docs['parentProfiles/p$i'] = {
          'childrenIds': ['s1'],
        };
        docs['users/p$i'] = {'name': 'P$i'};
      }
      final repo = AcademyAccountsRepository(
        functions: _UnusedFunctions(),
        firestore: _Store(docs),
      );
      final hits = await repo.listLinkedParentsForStudent('s1');
      expect(hits, hasLength(3));
    });

    test('propagates Firestore query failures', () async {
      final store = _Store({})
        ..queryError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      final repo = AcademyAccountsRepository(
        functions: _UnusedFunctions(),
        firestore: store,
      );
      await expectLater(
        () => repo.listLinkedParentsForStudent('s1'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  test('access card default loader no longer embeds Firestore queries', () {
    final source = File(
      'lib/features/accounts/presentation/admin_account_access_card.dart',
    ).readAsStringSync();
    expect(source, contains('listLinkedParentsForStudent'));
    expect(source, isNot(contains('parentProfiles')));
    expect(source, isNot(contains('package:cloud_firestore')));
    expect(source, isNot(contains('_defaultParents')));
  });
}
