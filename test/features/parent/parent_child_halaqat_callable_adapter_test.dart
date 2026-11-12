import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/parent/data/parent_child_halaqat_response.dart';

import '../../support/fake_callables.dart';

const _callable = 'getParentChildHalaqat';

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

  test('reads Halaqat only through the callable with {studentId}', () async {
    functions.handlers[_callable] = (_) => {'halaqat': const []};
    expect(await ds.getHalaqatForStudent(' s1 '), isEmpty);
    expect(functions.calledNames, [_callable]);
    expect(functions.payloadOf(_callable), {'studentId': 's1'});
  });

  test('blank student id makes no call', () async {
    expect(await ds.getHalaqatForStudent('  '), isEmpty);
    expect(functions.calledNames, isEmpty);
  });

  test('maps id and name; a blank name falls back to the id', () async {
    functions.handlers[_callable] = (_) => <Object?, Object?>{
      'halaqat': [
        <Object?, Object?>{
          'id': 'h1',
          'name': ' حلقة الفجر ',
          'teacherId': 't1',
          'supervisorId': 'sup1',
        },
        {'id': 'h2', 'name': ''},
        'junk',
        {'name': 'no id'},
      ],
    };
    final rows = await ds.getHalaqatForStudent('s1');
    expect(rows, [(id: 'h1', name: 'حلقة الفجر'), (id: 'h2', name: 'h2')]);
  });

  test('parser keeps only the projected fields', () {
    final rows = parseParentChildHalaqatResponse({
      'halaqat': [
        {
          'id': 'h1',
          'name': 'H1',
          'teacherId': 't1',
          'supervisorId': 'sup1',
          'studentIds': ['s1', 's2'],
          'meetingLink': 'https://meet.example.test/x',
        },
      ],
    });
    final row = rows.single;
    expect(
      [row.id, row.name, row.teacherId, row.supervisorId],
      ['h1', 'H1', 't1', 'sup1'],
    );
  });

  for (final (label, data) in [
    ('null data', null),
    ('missing halaqat key', const <String, Object?>{}),
    ('halaqat not a list', const {'halaqat': 'x'}),
  ]) {
    test('malformed response ($label) is an error', () async {
      functions.handlers[_callable] = (_) => data;
      expect(
        await failureOf(ds.getHalaqatForStudent('s1')),
        kParentChildHalaqatLoadFailedMessage,
      );
    });
  }

  test(
    'Arabic server rejection is shown; gate/transport text is not',
    () async {
      functions.handlers[_callable] = (_) => throw FakeFunctionsError(
        'permission-denied',
        'هذا الطالب غير مرتبط بحسابك',
      );
      expect(
        await failureOf(ds.getHalaqatForStudent('s9')),
        'هذا الطالب غير مرتبط بحسابك',
      );

      functions.handlers[_callable] = (_) => throw FakeFunctionsError(
        'failed-precondition',
        'Backend feature "getParentChildHalaqat" is disabled',
      );
      expect(
        await failureOf(ds.getHalaqatForStudent('s1')),
        kParentChildHalaqatLoadFailedMessage,
      );

      functions.handlers[_callable] = (_) =>
          throw FakeFunctionsError('unauthenticated', 'x');
      expect(
        await failureOf(ds.getHalaqatForStudent('s1')),
        kParentChildHalaqatSignedOutMessage,
      );
    },
  );

  test('server projection is exactly id, name, teacherId, supervisorId', () {
    final src = File(
      'functions/src/halaqa/parentHalaqaFunctions.ts',
    ).readAsStringSync();
    final body = RegExp(
      r'export interface ParentChildHalaqa \{([^}]*)\}',
    ).firstMatch(src)!.group(1)!;
    final serverKeys = RegExp(
      r'^\s*(\w+):',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!).toSet();
    expect(serverKeys, {'id', 'name', 'teacherId', 'supervisorId'});
  });

  test('the parent datasource never queries halaqat directly', () {
    final src = File(
      'lib/features/parent/data/data_source/parent_remote_datasource_impl.dart',
    ).readAsStringSync();
    expect(src.contains('FirestoreCollections.halaqat)'), isFalse);
  });
}
