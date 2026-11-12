import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/parent/data/parent_child_halaqat_response.dart';
import 'package:rafiq_academy/features/parent/data/parent_child_schedule_response.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/halaqa_schedule_source.dart';

import '../../support/fake_callables.dart';

const _callable = 'getParentChildSchedule';

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

  test('reads the schedule only through the callable with '
      '{studentId, halaqaId}', () async {
    functions.handlers[_callable] = (_) => {
      'halaqaId': 'h1',
      'name': 'حلقة الفجر',
      'schedule': [
        {'day': 'السبت', 'startTime': '06:00', 'endTime': '07:00'},
      ],
    };
    final source = await ds.getChildHalaqaSchedule(
      studentId: 's1',
      halaqaId: 'h1',
    );
    expect(functions.calledNames, [_callable]);
    expect(functions.payloadOf(_callable), {
      'studentId': 's1',
      'halaqaId': 'h1',
    });
    expect(
      source,
      const HalaqaScheduleSource(
        halaqaId: 'h1',
        name: 'حلقة الفجر',
        schedule: [
          HalaqaScheduleSlot(
            day: 'السبت',
            startTime: '06:00',
            endTime: '07:00',
          ),
        ],
      ),
    );
  });

  for (final (label, data) in [
    ('null data', null),
    ('missing schedule key', const <String, Object?>{'halaqaId': 'h1'}),
    ('schedule not a list', const {'halaqaId': 'h1', 'schedule': 'x'}),
    ('another Halaqa', const {'halaqaId': 'h2', 'schedule': <Object?>[]}),
  ]) {
    test('malformed response ($label) is an error', () async {
      functions.handlers[_callable] = (_) => data;
      expect(
        await failureOf(ds.getChildHalaqaSchedule(studentId: 's1', halaqaId: 'h1')),
        kParentChildScheduleLoadFailedMessage,
      );
    });
  }

  test('Arabic server rejection is shown; gate/transport text is not', () async {
    functions.handlers[_callable] = (_) => throw FakeFunctionsError(
      'permission-denied',
      'الطالب ليس ضمن هذه الحلقة',
    );
    expect(
      await failureOf(ds.getChildHalaqaSchedule(studentId: 's1', halaqaId: 'h2')),
      'الطالب ليس ضمن هذه الحلقة',
    );

    functions.handlers[_callable] = (_) => throw FakeFunctionsError(
      'failed-precondition',
      'Backend feature "getParentChildSchedule" is disabled',
    );
    expect(
      await failureOf(ds.getChildHalaqaSchedule(studentId: 's1', halaqaId: 'h1')),
      kParentChildScheduleLoadFailedMessage,
    );

    functions.handlers[_callable] = (_) =>
        throw FakeFunctionsError('unauthenticated', 'x');
    expect(
      await failureOf(ds.getChildHalaqaSchedule(studentId: 's1', halaqaId: 'h1')),
      kParentChildHalaqatSignedOutMessage,
    );
  });

  test('server projection is exactly halaqaId, name and slot times', () {
    final src = File(
      'functions/src/halaqa/parentScheduleFunctions.ts',
    ).readAsStringSync();
    Set<String> keysOf(String name) {
      final body = RegExp(
        'export interface $name \\{([^}]*)\\}',
      ).firstMatch(src)!.group(1)!;
      return RegExp(
        r'^\s*(\w+):',
        multiLine: true,
      ).allMatches(body).map((m) => m.group(1)!).toSet();
    }

    expect(keysOf('ParentChildSchedule'), {'halaqaId', 'name', 'schedule'});
    expect(keysOf('ParentScheduleSlot'), {'day', 'startTime', 'endTime'});
  });
}
