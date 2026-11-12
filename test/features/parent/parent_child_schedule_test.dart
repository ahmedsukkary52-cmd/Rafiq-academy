import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/data/parent_child_halaqat_response.dart';
import 'package:rafiq_academy/features/parent/data/parent_child_schedule_response.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_child_weekly_sessions_usecase.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart';
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_state.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_schedule_page.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_child_access.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/halaqa_schedule_source.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _FakeParentBloc extends Fake implements ParentBloc {
  _FakeParentBloc(this.state);

  @override
  final ParentState state;

  @override
  Stream<ParentState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}
}

typedef _Responder =
    Future<Either<Failure, HalaqaScheduleSource>> Function(
      String studentId,
      String halaqaId,
    );

class _FakeParentRepository extends Fake implements ParentRepository {
  _FakeParentRepository(this.respond);

  _Responder respond;
  final List<(String, String)> requested = [];

  @override
  Future<Either<Failure, HalaqaScheduleSource>> getChildHalaqaSchedule({
    required String studentId,
    required String halaqaId,
  }) {
    requested.add((studentId, halaqaId));
    return respond(studentId, halaqaId);
  }
}

const _fajr = HalaqaScheduleSource(
  halaqaId: 'h1',
  name: 'حلقة الفجر',
  schedule: [
    HalaqaScheduleSlot(day: 'السبت', startTime: '06:00', endTime: '07:00'),
  ],
);

void main() {
  group('parseParentChildScheduleResponse', () {
    test('keeps only the name and slot times', () {
      final source = parseParentChildScheduleResponse({
        'halaqaId': 'h1',
        'name': ' حلقة الفجر ',
        'schedule': [
          {
            'day': ' السبت ',
            'startTime': '06:00',
            'endTime': '07:00',
            'slotId': 'slot-a',
            'meetingLink': 'https://meet.example.test/x',
          },
          'not-a-slot',
          {'day': 7},
        ],
        'studentIds': ['s1', 's9'],
        'teacherId': 't1',
      }, expectedHalaqaId: 'h1');
      expect(source.halaqaId, 'h1');
      expect(source.name, 'حلقة الفجر');
      expect(source.schedule, const [
        HalaqaScheduleSlot(day: 'السبت', startTime: '06:00', endTime: '07:00'),
        HalaqaScheduleSlot(day: '', startTime: '', endTime: ''),
      ]);
      expect(source.schedule.first.slotId, isNull);
    });

    test('a missing schedule list is a contract break', () {
      for (final data in <Object?>[
        null,
        'x',
        <String, Object?>{'halaqaId': 'h1'},
        <String, Object?>{'halaqaId': 'h1', 'schedule': 'x'},
      ]) {
        expect(
          () => parseParentChildScheduleResponse(data, expectedHalaqaId: 'h1'),
          throwsFormatException,
          reason: '$data',
        );
      }
    });

    test('a response for another Halaqa is rejected', () {
      expect(
        () => parseParentChildScheduleResponse({
          'halaqaId': 'h2',
          'schedule': const [],
        }, expectedHalaqaId: 'h1'),
        throwsFormatException,
      );
    });

    test('error messages: Arabic server text as-is, otherwise generic', () {
      expect(
        parentChildScheduleErrorMessage('unauthenticated', 'x'),
        kParentChildHalaqatSignedOutMessage,
      );
      expect(
        parentChildScheduleErrorMessage(
          'permission-denied',
          'الطالب ليس ضمن هذه الحلقة',
        ),
        'الطالب ليس ضمن هذه الحلقة',
      );
      for (final message in [null, '', 'Backend disabled', 'INTERNAL']) {
        expect(
          parentChildScheduleErrorMessage('internal', message),
          kParentChildScheduleLoadFailedMessage,
        );
      }
      expect(kParentChildScheduleCallable, 'getParentChildSchedule');
    });
  });

  group('GetChildWeeklySessionsUseCase', () {
    test('maps the callable schedule into weekly sessions', () async {
      final repo = _FakeParentRepository((_, _) async => const Right(_fajr));
      final result = await GetChildWeeklySessionsUseCase(
        repo,
        now: () => DateTime(2026, 11, 10, 9),
      )(const ChildWeeklySessionsParams(studentId: ' s1 ', halaqaId: ' h1 '));
      expect(repo.requested, [('s1', 'h1')]);
      final sessions = result.getOrElse((_) => fail('expected sessions'));
      expect(sessions, hasLength(1));
      expect(sessions.single.title, 'حلقة الفجر');
      expect(sessions.single.startAt.weekday, DateTime.saturday);
      expect(sessions.single.startAt.hour, 6);
    });

    test('no Halaqa means no sessions and no request', () async {
      final repo = _FakeParentRepository((_, _) async => const Right(_fajr));
      final result = await GetChildWeeklySessionsUseCase(
        repo,
      )(const ChildWeeklySessionsParams(studentId: 's1', halaqaId: ' '));
      expect(result.getOrElse((_) => fail('expected empty')), isEmpty);
      expect(repo.requested, isEmpty);
    });

    test('a missing student id fails validation without a request', () async {
      final repo = _FakeParentRepository((_, _) async => const Right(_fajr));
      final result = await GetChildWeeklySessionsUseCase(
        repo,
      )(const ChildWeeklySessionsParams(studentId: ' ', halaqaId: 'h1'));
      expect(result.isLeft(), isTrue);
      expect(repo.requested, isEmpty);
    });

    test('server failures pass through', () async {
      final repo = _FakeParentRepository(
        (_, _) async => const Left(ServerFailure('الطالب ليس ضمن هذه الحلقة')),
      );
      final result = await GetChildWeeklySessionsUseCase(
        repo,
      )(const ChildWeeklySessionsParams(studentId: 's1', halaqaId: 'h1'));
      expect(
        result.getLeft().toNullable()?.message,
        'الطالب ليس ضمن هذه الحلقة',
      );
    });
  });

  group('ParentSchedulePage', () {
    late _FakeParentRepository repo;

    setUp(() {
      repo = _FakeParentRepository((_, _) async => const Right(_fajr));
      if (sl.isRegistered<ParentRepository>()) sl.unregister<ParentRepository>();
      sl.registerLazySingleton<ParentRepository>(() => repo);
    });

    tearDown(() {
      if (sl.isRegistered<ParentRepository>()) sl.unregister<ParentRepository>();
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      List<String> children = const ['s1'],
      List<ParentChildSnapshot> snapshots = const [
        ParentChildSnapshot(
          studentId: 's1',
          name: 'سارة',
          halaqaId: 'h1',
          halaqaName: 'حلقة الفجر',
        ),
      ],
      String? studentId,
    }) async {
      final bloc = _FakeParentBloc(
        ParentState(
          parentId: 'parent1',
          childrenIds: children,
          childrenSnapshots: snapshots,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ParentBloc>.value(
            value: bloc,
            child: ParentSchedulePage(studentId: studentId),
          ),
        ),
      );
    }

    testWidgets('loads the schedule through the parent callable', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(repo.requested, [('s1', 'h1')]);
      expect(find.text('حلقة الفجر'), findsWidgets);
      expect(find.byType(AppErrorWidget), findsNothing);
    });

    testWidgets('a callable failure shows its message and retry reloads', (
      tester,
    ) async {
      repo.respond = (_, _) async =>
          const Left(ServerFailure('الطالب ليس ضمن هذه الحلقة'));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text('الطالب ليس ضمن هذه الحلقة'), findsOneWidget);

      repo.respond = (_, _) async => const Right(_fajr);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(repo.requested, [('s1', 'h1'), ('s1', 'h1')]);
      expect(find.byType(AppErrorWidget), findsNothing);
    });

    testWidgets('an unlinked child is denied without calling the server', (
      tester,
    ) async {
      await pumpPage(tester, studentId: 's9');
      await tester.pumpAndSettle();
      expect(repo.requested, isEmpty);
      expect(find.text(ParentChildAccess.deniedMessage), findsOneWidget);
    });

    testWidgets('a child without a Halaqa shows the empty state', (
      tester,
    ) async {
      await pumpPage(
        tester,
        snapshots: const [ParentChildSnapshot(studentId: 's1', name: 'سارة')],
      );
      await tester.pumpAndSettle();
      expect(repo.requested, isEmpty);
      expect(
        find.text('لا توجد جلسات من جدول الحلقة لهذا الأسبوع.'),
        findsOneWidget,
      );
    });

    testWidgets('a pending request shows no stale sessions', (tester) async {
      final pending = Completer<Either<Failure, HalaqaScheduleSource>>();
      repo.respond = (_, _) => pending.future;
      await pumpPage(tester);
      await tester.pump();
      expect(repo.requested, [('s1', 'h1')]);
      expect(find.text('حلقة الفجر'), findsNothing);
      pending.complete(const Right(_fajr));
      await tester.pumpAndSettle();
      expect(find.text('حلقة الفجر'), findsWidgets);
    });
  });

  test('the parent module never reads halaqat directly (J.10)', () {
    final offenders = <String>[];
    for (final file in Directory(
      'lib/features/parent',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final src = file.readAsStringSync();
      for (final pattern in [
        'FirestoreCollections.halaqat',
        "collection('halaqat')",
        'collection("halaqat")',
        'GetWeeklySessionsUseCase',
        'ScheduleRepository',
        'schedule/data/',
      ]) {
        if (src.contains(pattern)) offenders.add('${file.path}: $pattern');
      }
    }
    expect(offenders, isEmpty);
  });
}
