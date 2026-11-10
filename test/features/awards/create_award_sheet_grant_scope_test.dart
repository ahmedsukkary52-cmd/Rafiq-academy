import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/awards/domain/award_grant_scope.dart';
import 'package:rafiq_academy/features/awards/domain/award_recipient_selection.dart';
import 'package:rafiq_academy/features/awards/domain/award_submission_id.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/awards/domain/unresolved_award_store.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_bloc.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_event.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_state.dart';
import 'package:rafiq_academy/features/awards/presentation/pages/awards_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/features/teacher/presentation/teacher_award_grant_scope.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_roster.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _TeacherBlocStub extends Cubit<TeacherState> implements TeacherBloc {
  _TeacherBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AwardsBlocStub extends Cubit<AwardsState> implements AwardsBloc {
  _AwardsBlocStub() : super(const AwardsState());

  final events = <AwardsEvent>[];

  @override
  void add(AwardsEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScopeSource implements AwardGrantScopeSource {
  _ScopeSource(this.state);

  final _controller = StreamController<AwardGrantScope>.broadcast();

  @override
  AwardGrantScope state;

  @override
  Stream<AwardGrantScope> get stream => _controller.stream;

  void emit(AwardGrantScope next) {
    state = next;
    _controller.add(next);
  }
}

class _MemoryStore implements UnresolvedAwardStore {
  final records = <String, String>{};

  @override
  Future<String?> read(String key) async => records[key];

  @override
  Future<void> write(String key, String record) async => records[key] = record;

  @override
  Future<void> remove(String key) async => records.remove(key);
}

class _RosterReader implements HalaqaRosterReader {
  final calls = <String>[];
  final failing = <String>{};

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  ) async {
    calls.add(halaqaId);
    if (failing.contains(halaqaId)) {
      return const Left(ServerFailure('تعذر تحميل طلاب الحلقة'));
    }
    return Right([
      HalaqaStudentSummaryEntity(uid: 'st-$halaqaId', name: 'طالب $halaqaId'),
    ]);
  }
}

HalaqaEntity _halaqa(String id, String name) => HalaqaEntity(
  id: id,
  name: name,
  teacherId: 'teacher1',
  supervisorId: 'sup1',
  studentIds: const [],
  schedule: const [],
  status: 'active',
);

const _h1 = AwardHalaqaOption(id: 'h1', name: 'حلقة الفجر');
const _h2 = AwardHalaqaOption(id: 'h2', name: 'حلقة العصر');
const _ahmad = AwardRecipientStudent(uid: 's1', name: 'أحمد');

const _seeded = AwardGrantScope(
  halaqat: [_h1],
  rosterHalaqaId: 'h1',
  roster: [_ahmad],
);

final _submit = find.byKey(const Key('create-award-submit'));

late _RosterReader _reader;

Future<_AwardsBlocStub> _pumpSheet(
  WidgetTester tester,
  AwardGrantScopeSource scope,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final awards = _AwardsBlocStub();
  final auth = _AuthBlocStub(
    AuthAuthenticated(
      UserEntity(
        uid: 'teacher1',
        name: 'معلم',
        role: 'teacher',
        isActive: true,
        createdAt: DateTime(2026),
      ),
    ),
  );
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp(
        home: Scaffold(
          body: BlocProvider<AwardsBloc>.value(
            value: awards,
            child: CreateAwardSheet(
              halaqaId: 'h1',
              grantScope: scope,
              preset: AwardType.performanceStars,
              preselectedStudentId: 's1',
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return awards;
}

AppButton _submitButton(WidgetTester tester) =>
    tester.widget<AppButton>(_submit);

void main() {
  group('teacherAwardGrantScope', () {
    test('maps halaqat and the loaded roster in order', () {
      final scope = teacherAwardGrantScope(
        TeacherState(
          halaqat: [_halaqa('h2', 'حلقة العصر'), _halaqa('h1', 'حلقة الفجر')],
          studentsHalaqaId: 'h1',
          students: const [
            HalaqaStudentSummaryEntity(
              uid: 's1',
              name: 'أحمد',
              profileImageUrl: 'https://img/s1',
            ),
            HalaqaStudentSummaryEntity(uid: 's2', name: 'محمد'),
          ],
        ),
      );

      expect(scope.halaqat.map((h) => '${h.id}:${h.name}'), [
        'h2:حلقة العصر',
        'h1:حلقة الفجر',
      ]);
      expect(scope.rosterHalaqaId, 'h1');
      expect(scope.roster.map((s) => '${s.uid}:${s.name}:${s.imageUrl}'), [
        's1:أحمد:https://img/s1',
        's2:محمد:null',
      ]);
    });

    test('an empty teacher state yields an empty scope', () {
      final scope = teacherAwardGrantScope(const TeacherState());
      expect(scope.halaqat, isEmpty);
      expect(scope.rosterHalaqaId, isNull);
      expect(scope.roster, isEmpty);
    });

    test('the source follows TeacherBloc emissions', () async {
      final bloc = _TeacherBlocStub(const TeacherState());
      addTearDown(bloc.close);
      final source = TeacherAwardGrantScopeSource(bloc);
      expect(source.state.halaqat, isEmpty);

      final next = expectLater(
        source.stream.map((s) => s.halaqat.map((h) => h.id).toList()),
        emits(['h1']),
      );
      bloc.emit(TeacherState(halaqat: [_halaqa('h1', 'حلقة الفجر')]));
      await next;
      expect(source.state.halaqat.single.name, 'حلقة الفجر');
    });
  });

  group('CreateAwardSheet grant scope', () {
    setUp(() async {
      AwardSubmissionId.clearUnresolvedRegistry();
      await sl.reset();
      _reader = _RosterReader();
      sl.registerLazySingleton<UnresolvedAwardStore>(_MemoryStore.new);
      sl.registerLazySingleton<GetHalaqaStudentsUseCase>(
        () => GetHalaqaStudentsUseCase(_reader),
      );
    });

    tearDown(() async {
      AwardSubmissionId.clearUnresolvedRegistry();
      await sl.reset();
    });

    testWidgets('an empty scope shows no halaqat and cannot grant', (
      tester,
    ) async {
      await _pumpSheet(tester, _ScopeSource(const AwardGrantScope()));

      expect(find.text('لا توجد حلقات محمّلة'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(_submitButton(tester).onPressed, isNull);
    });

    testWidgets('a preloaded roster is used without refetching', (
      tester,
    ) async {
      await _pumpSheet(tester, _ScopeSource(_seeded));

      expect(_reader.calls, isEmpty);
      expect(find.text('حلقة الفجر'), findsWidgets);
      final ahmad = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'أحمد'),
      );
      expect(ahmad.value, isTrue);
      expect(_submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('rebuilds when the scope emits new halaqat', (tester) async {
      final scope = _ScopeSource(const AwardGrantScope());
      await _pumpSheet(tester, scope);
      expect(find.text('لا توجد حلقات محمّلة'), findsOneWidget);

      scope.emit(const AwardGrantScope(halaqat: [_h1]));
      await tester.pump();
      await tester.pump();

      expect(find.text('لا توجد حلقات محمّلة'), findsNothing);
      expect(
        find.widgetWithText(CheckboxListTile, 'حلقة الفجر'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CheckboxListTile, 'طالب h1'), findsOneWidget);
    });

    testWidgets('selecting another halaqa loads its roster and shows errors', (
      tester,
    ) async {
      _reader.failing.add('h2');
      await _pumpSheet(
        tester,
        _ScopeSource(
          const AwardGrantScope(
            halaqat: [_h1, _h2],
            rosterHalaqaId: 'h1',
            roster: [_ahmad],
          ),
        ),
      );
      expect(_reader.calls, isEmpty);

      final h2 = find.widgetWithText(CheckboxListTile, 'حلقة العصر');
      await tester.ensureVisible(h2);
      await tester.tap(h2);
      await tester.pump();
      await tester.pump();

      expect(_reader.calls, ['h2']);
      expect(find.text('تعذر تحميل طلاب الحلقة'), findsOneWidget);
    });

    testWidgets('submission payload keeps halaqa ids, names and recipients', (
      tester,
    ) async {
      final awards = await _pumpSheet(tester, _ScopeSource(_seeded));

      await tester.ensureVisible(_submit);
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump();

      final award = (awards.events.single as GrantAwardEvent).award;
      expect(award.halaqaId, 'h1');
      expect(award.halaqaIds, ['h1']);
      expect(award.halaqaNames, ['حلقة الفجر']);
      expect(award.halaqaName, 'حلقة الفجر');
      expect(award.recipientStudentIds, ['s1']);
      expect(award.studentId, 's1');
      expect(award.studentName, 'أحمد');
      expect(award.grantedBy, 'teacher1');
      expect(award.type, AwardType.performanceStars.formCategory);
      expect(award.title, AwardType.performanceStars.title);
    });
  });
}
