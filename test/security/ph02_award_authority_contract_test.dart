// Firestore reference types are @sealed; tests may still fake them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/awards/data/datasources/award_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/awards/data/models/granted_award_model.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';

import '../support/fake_callables.dart';

/// Hands out document ids only; any read or write through it throws.
class _IdOnlyFirestore extends Fake implements FirebaseFirestore {
  final collections = <String>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    collections.add(path);
    return _IdOnlyCollection();
  }
}

class _IdOnlyCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _IdOnlyDoc(path ?? 'generatedAwardId');
}

class _IdOnlyDoc extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _IdOnlyDoc(this.id);

  @override
  final String id;
}

GrantedAwardModel _award({List<String> recipients = const ['s1', 's2']}) =>
    GrantedAwardModel(
      id: 'awardSubmission01',
      studentId: '',
      studentName: 'أحمد',
      type: AwardType.performanceStars,
      title: 'نجم الحلقة',
      grantedBy: 'teacher1',
      halaqaId: 'h1',
      grantedAt: DateTime(2026, 9, 1),
      recipientStudentIds: recipients,
    );

/// PH-02 — award counters (`points` / `totalStars`) are credited only by the
/// `grantAward` callable; the client sends intent, never an amount. The rules
/// side is covered by `rules_test/ph02_backend_authority.rules.test.mjs`.
void main() {
  late FakeFunctions functions;
  late _IdOnlyFirestore firestore;
  late AwardsRemoteDatasourceImpl datasource;

  setUp(() {
    functions = FakeFunctions()..handlers['grantAward'] = (_) => null;
    firestore = _IdOnlyFirestore();
    datasource = AwardsRemoteDatasourceImpl(
      firestore: firestore,
      storage: UnusedStorage(),
      functions: functions,
    );
  });

  test('grant goes through grantAward with a replay-safe award id', () async {
    await datasource.grantAward(_award());

    expect(functions.calledNames, ['grantAward']);
    final payload = functions.payloadOf('grantAward') as Map;
    expect(payload['awardId'], 'awardSubmission01');
    expect(payload['type'], 'performance_stars');
    expect(payload['recipientStudentIds'], ['s1', 's2']);
    expect(payload['halaqaIds'], ['h1']);
  });

  test('client sends no amount, counter or granter identity', () async {
    await datasource.grantAward(_award());

    final payload = functions.payloadOf('grantAward') as Map;
    for (final key in const [
      'points',
      'totalStars',
      'stars',
      'amount',
      'grantedBy',
      'studentProfiles',
    ]) {
      expect(payload.containsKey(key), isFalse, reason: key);
    }
    expect(firestore.collections, isEmpty);
  });

  test('no recipients is rejected before the server', () async {
    await expectLater(
      datasource.grantAward(_award(recipients: const [])),
      throwsA(isA<ServerException>()),
    );
    expect(functions.calls, isEmpty);
  });

  test('server denial surfaces as ServerException', () async {
    functions.handlers['grantAward'] = (_) =>
        throw FakeFunctionsError('permission-denied', 'غير مسموح');

    await expectLater(
      datasource.grantAward(_award()),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'غير مسموح'),
      ),
    );
  });
}
