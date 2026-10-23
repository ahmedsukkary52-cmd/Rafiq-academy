import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/parent/data/parent_achievements_response.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';

import '../../support/fake_callables.dart';

const _callable = 'getParentAchievements';

Map<String, Object?> _entry(String id, {Object? studentId = 's1'}) => {
  'id': id,
  'studentId': studentId,
  'type': 'custom',
  'title': 'حفظ جزء',
  'description': 'سبب',
  'imageUrl': null,
  'issuedBy': 'teacher1',
  'dateMillis': 1790000000000,
  'recipientStudentIds': ['s1'],
};

void main() {
  late FakeFunctions functions;
  late ParentRemoteDatasourceImpl ds;

  setUp(() {
    functions = FakeFunctions();
    ds = ParentRemoteDatasourceImpl(
      firestore: UnusedFirestore(),
      storage: UnusedStorage(),
      functions: functions,
    );
  });

  Future<String> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on ServerException catch (e) {
      return e.message;
    }
    fail('expected ServerException');
  }

  group('request', () {
    test(
      'calls only getParentAchievements with {studentId} and no Firestore',
      () async {
        functions.handlers[_callable] = (_) => {'achievements': const []};
        await ds.getChildAchievements('s1');
        expect(functions.calledNames, [_callable]);
        expect(functions.payloadOf(_callable), {'studentId': 's1'});
      },
    );
  });

  group('response parsing', () {
    test('maps every server field into the model', () async {
      functions.handlers[_callable] = (_) => {
        'achievements': [_entry('a1')],
      };
      final items = await ds.getChildAchievements('s1');
      expect(items, hasLength(1));
      final a = items.single;
      expect(a.id, 'a1');
      expect(a.studentId, 's1');
      expect(a.type, AchievementType.custom);
      expect(a.title, 'حفظ جزء');
      expect(a.description, 'سبب');
      expect(a.imageUrl, isNull);
      expect(a.issuedBy, 'teacher1');
      expect(a.date, DateTime.fromMillisecondsSinceEpoch(1790000000000));
      expect(a.recipientStudentIds, ['s1']);
    });

    test('platform-shaped maps (Object? keys) are accepted', () async {
      functions.handlers[_callable] = (_) => <Object?, Object?>{
        'achievements': [
          <Object?, Object?>{..._entry('a1')},
        ],
      };
      final items = await ds.getChildAchievements('s1');
      expect(items.single.id, 'a1');
    });

    test('empty list is an empty result', () async {
      functions.handlers[_callable] = (_) => {'achievements': const []};
      expect(await ds.getChildAchievements('s1'), isEmpty);
    });

    test('entries that are not maps or have no id are skipped', () async {
      functions.handlers[_callable] = (_) => {
        'achievements': [
          'junk',
          null,
          {'title': 'no id'},
          {..._entry('a1'), 'id': ''},
          _entry('a2'),
        ],
      };
      final items = await ds.getChildAchievements('s1');
      expect(items.map((a) => a.id), ['a2']);
    });

    for (final (label, data) in [
      ('null data', null),
      ('a list instead of a map', const <Object?>[]),
      ('missing achievements key', const <String, Object?>{}),
      ('achievements not a list', const {'achievements': 'x'}),
    ]) {
      test(
        'malformed response ($label) is an error, not an empty list',
        () async {
          functions.handlers[_callable] = (_) => data;
          expect(
            await failureOf(ds.getChildAchievements('s1')),
            kParentAchievementsLoadFailedMessage,
          );
        },
      );
    }
  });

  group('callable errors', () {
    test('server Arabic rejection (unlinked child) is shown as-is', () async {
      functions.handlers[_callable] = (_) => throw FakeFunctionsError(
        'permission-denied',
        'هذا الطالب غير مرتبط بحسابك',
      );
      expect(
        await failureOf(ds.getChildAchievements('s9')),
        'هذا الطالب غير مرتبط بحسابك',
      );
    });

    test('unauthenticated maps to the signed-out message', () async {
      functions.handlers[_callable] = (_) =>
          throw FakeFunctionsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
      expect(
        await failureOf(ds.getChildAchievements('s1')),
        kParentAchievementsSignedOutMessage,
      );
    });

    for (final (code, message) in [
      (
        'failed-precondition',
        'Backend feature "getParentAchievements" is disabled until B-BILLING is Verified',
      ),
      ('internal', 'INTERNAL'),
      ('unavailable', 'Unable to resolve host'),
      ('not-found', 'NOT_FOUND'),
    ]) {
      test('$code with non-Arabic text never reaches the parent', () async {
        functions.handlers[_callable] = (_) =>
            throw FakeFunctionsError(code, message);
        expect(
          await failureOf(ds.getChildAchievements('s1')),
          kParentAchievementsLoadFailedMessage,
        );
      });
    }

    test('non-callable exception maps to the load-failed message', () async {
      functions.handlers[_callable] = (_) => throw StateError('boom');
      expect(
        await failureOf(ds.getChildAchievements('s1')),
        kParentAchievementsLoadFailedMessage,
      );
    });
  });

  test('Dart parser consumes exactly the fields the server projects', () {
    final src = File(
      'functions/src/awards/parentAchievementFunctions.ts',
    ).readAsStringSync();
    final body = RegExp(
      r'export interface ParentAchievement \{([^}]*)\}',
    ).firstMatch(src)!.group(1)!;
    final serverKeys = RegExp(
      r'^\s*(\w+):',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!).toSet();
    expect(serverKeys, {
      'id',
      'studentId',
      'type',
      'title',
      'description',
      'imageUrl',
      'issuedBy',
      'dateMillis',
      'recipientStudentIds',
    });
    final model = parseParentAchievementsResponse({
      'achievements': [_entry('a1')],
    }).single;
    expect(model.id, isNotEmpty);
    expect(model.date.millisecondsSinceEpoch, 1790000000000);
  });
}
