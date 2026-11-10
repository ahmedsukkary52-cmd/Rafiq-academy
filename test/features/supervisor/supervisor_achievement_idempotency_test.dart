import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/awards/data/award_grant_errors.dart';
import 'package:rafiq_academy/features/awards/data/shared_preferences_unresolved_award_store.dart';
import 'package:rafiq_academy/features/awards/domain/award_submission_id.dart';
import 'package:rafiq_academy/features/awards/domain/unresolved_award_store.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/read_models/supervisor_day_board.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/admit_student_to_halaqa_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/issue_achievement_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/payment_review_usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/submit_supervisor_report_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/pages/supervisor_grant_award_page.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/halaqa_roster.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_callables.dart';

typedef _E<T> = Either<Failure, T>;

const _opId = 'achSubmission01';

const _halaqa = HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: ['s1'],
  schedule: [],
  status: 'active',
);

AchievementIssueEntity _entity({String id = _opId}) => AchievementIssueEntity(
  achievementId: id,
  studentId: 's1',
  type: 'star',
  title: 'حفظ جزء عم',
  issuedBy: 'sup1',
  halaqaId: 'h1',
);

class _Halaqat extends Fake implements GetSupervisedHalaqatUseCase {
  @override
  Future<_E<List<HalaqaEntity>>> call(SupervisorIdParams p) async =>
      const Right([_halaqa]);
}

class _Board extends Fake implements GetSupervisorDayBoardUseCase {
  @override
  Future<_E<SupervisorDayBoard>> call(SupervisorDayBoardParams p) async =>
      const Right(SupervisorDayBoard.empty);
}

class _Absence extends Fake implements GetSupervisedAbsenceRequestsUseCase {
  @override
  Future<_E<List<AbsenceRequestEntity>>> call(
    SupervisedAbsenceRequestsParams p,
  ) async => const Right([]);
}

/// Each call stays in flight until the test completes its result.
class _Issue extends Fake implements IssueAchievementUseCase {
  final calls = <AchievementIssueEntity>[];
  final results = <Completer<_E<Unit>>>[];

  @override
  Future<_E<Unit>> call(AchievementIssueEntity p) {
    calls.add(p);
    final c = Completer<_E<Unit>>();
    results.add(c);
    return c.future;
  }
}

class _UnusedReport extends Fake implements SubmitSupervisorReportUseCase {}

class _UnusedAdmit extends Fake implements AdmitStudentToHalaqaUseCase {}

class _UnusedTransfer extends Fake
    implements TransferStudentBetweenHalaqatUseCase {}

class _UnusedPayments extends Fake implements GetSupervisedPaymentsUseCase {}

class _UnusedReview extends Fake implements ReviewPaymentProofUseCase {}

class _UnusedRegister extends Fake implements RegisterNewStudentUseCase {}

SupervisorBloc _bloc(_Issue issue) => SupervisorBloc(
  getSupervisedHalaqat: _Halaqat(),
  getSupervisorDayBoard: _Board(),
  getSupervisedAbsenceRequests: _Absence(),
  issueAchievement: issue,
  submitSupervisorReport: _UnusedReport(),
  admitStudentToHalaqa: _UnusedAdmit(),
  transferStudentBetweenHalaqat: _UnusedTransfer(),
  getSupervisedPayments: _UnusedPayments(),
  reviewPaymentProof: _UnusedReview(),
  registerNewStudent: _UnusedRegister(),
);

class _TeacherRepo extends Fake implements TeacherRepository {
  @override
  Future<_E<List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  ) async => const Right([HalaqaStudentSummaryEntity(uid: 's1', name: 'أحمد')]);
}

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledStore implements UnresolvedAwardStore {
  final records = <String, String>{};
  bool failWrites = false;
  int writes = 0;
  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async => records[key];

  @override
  Future<void> write(String key, String record) async {
    writes++;
    final gate = writeGate;
    if (gate != null) await gate.future;
    if (failWrites) throw StateError('disk full');
    records[key] = record;
  }

  @override
  Future<void> remove(String key) async => records.remove(key);
}

const _staffKey = 'awards.unresolved.issueAchievement.staff.sup1';

final _supervisor = UserEntity(
  uid: 'sup1',
  name: 'مشرف',
  role: 'supervisor',
  isActive: true,
  createdAt: DateTime(2026),
);

final _submit = find.byKey(const Key('supervisor-award-submit'));
final _panel = find.byKey(const Key('award-unresolved-panel'));
final _page = find.byType(SupervisorGrantAwardPage);

/// Bounded pumps: snackbars and the in-flight state keep scheduling frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<SupervisorBloc> _pumpHost(WidgetTester tester, _Issue issue) async {
  // Tall enough that the error snackbar never covers the submit button.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final bloc = _bloc(issue)..add(const LoadSupervisedHalaqatEvent('sup1'));
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: _AuthBlocStub(AuthAuthenticated(_supervisor)),
        ),
        BlocProvider<SupervisorBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SupervisorGrantAwardPage(
                    preselectedStudentId: 's1',
                    preselectedHalaqaId: 'h1',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return bloc;
}

Future<void> _openAndFill(WidgetTester tester, String title) async {
  await tester.tap(find.text('open'));
  await _settle(tester);
  await tester.enterText(find.byType(TextField), title);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester, {bool twice = false}) async {
  await tester.tap(_submit);
  if (twice) await tester.tap(_submit, warnIfMissed: false);
  await tester.pump();
}

Future<void> _close(WidgetTester tester, SupervisorBloc bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

void main() {
  group('supervisor achievement datasource', () {
    late FakeFunctions functions;
    late SupervisorRemoteDatasourceImpl datasource;

    setUp(() {
      functions = FakeFunctions()
        ..handlers['issueAchievement'] = (_) => {
          'achievementId': _opId,
          'alreadyIssued': false,
        };
      datasource = SupervisorRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    test('issues through the callable only; no actor or credit sent', () async {
      await datasource.issueAchievement(_entity());

      expect(functions.calledNames, ['issueAchievement']);
      final payload = functions.payloadOf('issueAchievement') as Map;
      expect(payload, {
        'achievementId': _opId,
        'studentId': 's1',
        'halaqaId': 'h1',
        'type': 'star',
        'title': 'حفظ جزء عم',
      });
    });

    test('a timeout error and its retry send the same operation id', () async {
      functions.handlers['issueAchievement'] = (_) =>
          throw FakeFunctionsError('deadline-exceeded', 'DEADLINE_EXCEEDED');
      await expectLater(
        datasource.issueAchievement(_entity()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );

      functions.handlers['issueAchievement'] = (_) => {
        'achievementId': _opId,
        'alreadyIssued': true,
      };
      await datasource.issueAchievement(_entity());

      final ids = [
        for (final c in functions.calls) (c.$2 as Map)['achievementId'],
      ];
      expect(ids, [_opId, _opId]);
    });

    test('server rejections pass through; other errors after sending are '
        'unconfirmed', () async {
      functions.handlers['issueAchievement'] = (_) => throw FakeFunctionsError(
        'permission-denied',
        'الطالب ليس ضمن هذه الحلقة',
      );
      await expectLater(
        datasource.issueAchievement(_entity()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'الطالب ليس ضمن هذه الحلقة',
          ),
        ),
      );

      functions.handlers['issueAchievement'] = (_) =>
          throw StateError('socket closed');
      await expectLater(
        datasource.issueAchievement(_entity()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            kAwardGrantUnconfirmedMessage,
          ),
        ),
      );
    });

    test('the same id with a different payload surfaces as a confirmed '
        'rejection, not as success', () async {
      functions.handlers['issueAchievement'] = (_) => throw FakeFunctionsError(
        'failed-precondition',
        'معرّف العملية مستخدم لطلب مختلف.',
      );
      await expectLater(
        datasource.issueAchievement(_entity()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'معرّف العملية مستخدم لطلب مختلف.',
          ),
        ),
      );
    });

    test('a missing operation id never reaches the server', () async {
      await expectLater(
        datasource.issueAchievement(_entity(id: '')),
        throwsA(isA<ServerException>()),
      );
      expect(functions.calls, isEmpty);
    });
  });

  test(
    'supervisor bloc drops a duplicate issue while one is in flight',
    () async {
      final issue = _Issue();
      final bloc = _bloc(issue)
        ..add(IssueAchievementEvent(_entity()))
        ..add(IssueAchievementEvent(_entity()));
      await Future<void>.delayed(Duration.zero);
      expect(issue.calls, hasLength(1));

      issue.results.single.complete(const Right(unit));
      await Future<void>.delayed(Duration.zero);
      await bloc.close();
    },
  );

  group('supervisor grant page', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AwardSubmissionId.clearUnresolvedRegistry();
      await sl.reset();
      sl
        ..registerFactory<GetHalaqaStudentsUseCase>(
          () => GetHalaqaStudentsUseCase(_TeacherRepo()),
        )
        ..registerLazySingleton<UnresolvedAwardStore>(
          SharedPreferencesUnresolvedAwardStore.new,
        );
    });

    testWidgets('an unresolved issue survives an app restart: the same id and '
        'exact values are resent, and success clears the record', (
      tester,
    ) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');
      await _tapSubmit(tester);
      issue.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      Navigator.of(tester.element(_page)).pop();
      await _settle(tester);

      AwardSubmissionId.clearUnresolvedRegistry();
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(_panel, findsOneWidget);
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(identical(issue.calls.last, issue.calls.first), isFalse);
      expect(issue.calls.last, issue.calls.first);

      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(_page, findsNothing);
      expect(
        await sl<UnresolvedAwardStore>().read(
          'awards.unresolved.issueAchievement.staff.sup1',
        ),
        isNull,
      );
      await _close(tester, bloc);
    });

    testWidgets('an unreadable saved record blocks new issues until it is '
        'abandoned', (tester) async {
      SharedPreferences.setMockInitialValues({
        'awards.unresolved.issueAchievement.staff.sup1': '{"v":1,"id":',
      });
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');
      expect(_panel, findsOneWidget);
      expect(find.text(kAwardRecordUnreadableNotice), findsOneWidget);
      await _tapSubmit(tester);
      expect(issue.calls, isEmpty);

      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(_panel, findsNothing);
      await tester.enterText(find.byType(TextField), 'حفظ جزء عم');
      await tester.pump();
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(1));
      issue.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    tearDown(() {
      AwardSubmissionId.clearUnresolvedRegistry();
      return sl.reset();
    });

    testWidgets('while unresolved the page is locked to the exact pinned '
        'issue; leaving and returning restores it', (tester) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester);
      issue.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      expect(_panel, findsOneWidget);
      expect(find.text(kAwardGrantRetrySameLabel), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'حفظ جزء تبارك');
      await tester.pump();
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(identical(issue.calls.last, issue.calls.first), isTrue);
      expect(issue.calls.last.title, 'حفظ جزء عم');

      issue.results.last.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      Navigator.of(tester.element(_page)).pop();
      await _settle(tester);
      expect(_page, findsNothing);

      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(_panel, findsOneWidget);
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(3));
      expect(issue.calls.last.achievementId, issue.calls.first.achievementId);

      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(_page, findsNothing);
      await _close(tester, bloc);
    });

    testWidgets('abandon is confirmed explicitly and only then allows a new '
        'operation id', (tester) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester);
      issue.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('award-abandon')));
      await _settle(tester);
      expect(find.text(kAwardGrantAbandonWarning), findsOneWidget);
      await tester.tap(find.byKey(const Key('award-abandon-confirm')));
      await _settle(tester);
      expect(_panel, findsNothing);

      await tester.enterText(find.byType(TextField), 'حفظ جزء تبارك');
      await tester.pump();
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(issue.calls.last.title, 'حفظ جزء تبارك');
      expect(
        issue.calls.last.achievementId,
        isNot(issue.calls.first.achievementId),
      );
      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('an unconfirmed issue keeps the page; the retry reuses the id '
        'and success closes it', (tester) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester);
      expect(issue.calls, hasLength(1));
      expect(
        AwardSubmissionId.isValid(issue.calls.single.achievementId),
        isTrue,
      );

      issue.results.single.complete(
        const Left(ServerFailure(kAwardGrantUnconfirmedMessage)),
      );
      await _settle(tester);
      expect(_page, findsOneWidget);
      expect(find.text(kAwardGrantUnconfirmedMessage), findsOneWidget);

      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(issue.calls.last.achievementId, issue.calls.first.achievementId);

      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(_page, findsNothing);
      await _close(tester, bloc);
    });

    testWidgets('repeated taps send one issue; a later grant is a new '
        'operation', (tester) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester, twice: true);
      await _settle(tester);
      expect(issue.calls, hasLength(1));

      issue.results.single.complete(const Right(unit));
      await _settle(tester);
      expect(_page, findsNothing);

      await _openAndFill(tester, 'حفظ جزء عم');
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(
        issue.calls.last.achievementId,
        isNot(issue.calls.first.achievementId),
      );
      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('a definitive failure keeps the form; an edited payload is a '
        'new operation', (tester) async {
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester);
      issue.results.single.complete(
        const Left(ServerFailure('لا تملك صلاحية منح إنجازات في هذه الحلقة')),
      );
      await _settle(tester);
      expect(_page, findsOneWidget);
      expect(
        find.text('لا تملك صلاحية منح إنجازات في هذه الحلقة'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'حفظ جزء تبارك');
      await tester.pump();
      await _tapSubmit(tester);
      expect(issue.calls, hasLength(2));
      expect(issue.calls.last.title, 'حفظ جزء تبارك');
      expect(
        issue.calls.last.achievementId,
        isNot(issue.calls.first.achievementId),
      );
      issue.results.last.complete(const Right(unit));
      await _settle(tester);
      expect(_page, findsNothing);
      await _close(tester, bloc);
    });

    _ControlledStore useControlledStore() {
      final store = _ControlledStore();
      sl
        ..unregister<UnresolvedAwardStore>()
        ..registerLazySingleton<UnresolvedAwardStore>(() => store);
      return store;
    }

    testWidgets('while the issue is being saved the page is locked and '
        'nothing is sent', (tester) async {
      final store = useControlledStore();
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      store.writeGate = Completer<void>();
      await _tapSubmit(tester, twice: true);
      await _tapSubmit(tester);
      expect(store.writes, 1);
      expect(issue.calls, isEmpty);
      expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.byType(TextField),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );

      store.writeGate!.complete();
      await _settle(tester);
      expect(issue.calls, hasLength(1));
      expect(store.records[_staffKey], contains(issue.calls.single.achievementId));
      issue.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('a failed local save sends nothing; retrying the save sends '
        'exactly one issue', (tester) async {
      final store = useControlledStore()..failWrites = true;
      final issue = _Issue();
      final bloc = await _pumpHost(tester, issue);
      await _openAndFill(tester, 'حفظ جزء عم');

      await _tapSubmit(tester);
      await _settle(tester);
      expect(issue.calls, isEmpty);
      expect(store.records, isEmpty);
      expect(find.text(kAwardLocalSaveFailedMessage), findsOneWidget);
      expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);

      store.failWrites = false;
      await _tapSubmit(tester, twice: true);
      await _settle(tester);
      expect(issue.calls, hasLength(1));
      expect(store.records[_staffKey], contains(issue.calls.single.achievementId));
      issue.results.single.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });
  });
}
