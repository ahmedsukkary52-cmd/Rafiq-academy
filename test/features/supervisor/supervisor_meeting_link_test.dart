import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_operations_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/admin_operations_usecases.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_state.dart';
import 'package:rafiq_academy/features/supervisor/presentation/pages/supervisor_halaqa_detail_page.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

// Only `uid` is read; a Fake keeps the test independent of UserEntity's
// constructor fields.
class _FakeUser extends Fake implements UserEntity {
  @override
  String get uid => 'sup1';
}

class _FakeAuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(_FakeUser());

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _FakeSupervisorBloc extends Fake implements SupervisorBloc {
  _FakeSupervisorBloc(this._state);

  final SupervisorState _state;
  final _controller = StreamController<SupervisorState>.broadcast();
  final events = <SupervisorEvent>[];

  @override
  SupervisorState get state => _state;

  @override
  Stream<SupervisorState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(SupervisorEvent event) => events.add(event);

  @override
  Future<void> close() => _controller.close();
}

class _FakeOpsRepo extends Fake implements AdminOperationsRepository {
  final calls = <String>[];
  Failure? failure;

  @override
  Future<Either<Failure, MeetingLinkChange>> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  }) async {
    calls.add('$halaqaId:$meetingLink:$clear');
    if (failure != null) return Left(failure!);
    return const Right(MeetingLinkChange.set);
  }
}

HalaqaEntity _halaqa(String link) => HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [],
  meetingLink: link,
  status: 'active',
);

Future<_FakeSupervisorBloc> _pump(
  WidgetTester tester, {
  required String link,
  required _FakeOpsRepo repo,
}) async {
  await sl.reset();
  sl.registerFactory<SetHalaqaMeetingLinkUseCase>(
    () => SetHalaqaMeetingLinkUseCase(repo),
  );
  final bloc = _FakeSupervisorBloc(
    SupervisorState.initial().copyWith(halaqat: [_halaqa(link)]),
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc()),
        BlocProvider<SupervisorBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: const SupervisorHalaqaDetailPage(halaqaId: 'h1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  tearDown(() => sl.reset());

  group('B14 supervisor meeting link (add-only)', () {
    testWidgets('adds a link when none is set and reloads the halaqat', (
      tester,
    ) async {
      final repo = _FakeOpsRepo();
      final bloc = await _pump(tester, link: '', repo: repo);
      expect(find.text('لم يُضبط رابط الاجتماع بعد'), findsOneWidget);

      await tester.tap(find.byKey(const Key('supervisorAddMeetingLink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meetingLinkClear')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        'https://meet.example.com/new',
      );
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();

      expect(repo.calls, ['h1:https://meet.example.com/new:false']);
      expect(find.text('تم حفظ رابط الاجتماع'), findsOneWidget);
      expect(bloc.events.whereType<LoadSupervisedHalaqatEvent>(), hasLength(1));
    });

    testWidgets('an existing link is read-only for the supervisor', (
      tester,
    ) async {
      final repo = _FakeOpsRepo();
      await _pump(tester, link: 'https://meet.example.com/a', repo: repo);
      expect(find.text('رابط الاجتماع مضبوط'), findsOneWidget);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a server refusal is shown and nothing reloads', (
      tester,
    ) async {
      final repo = _FakeOpsRepo()..failure = const ServerFailure('غير مصرح');
      final bloc = await _pump(tester, link: '', repo: repo);
      await tester.tap(find.byKey(const Key('supervisorAddMeetingLink')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        'https://meet.example.com/new',
      );
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(find.text('لم يُحفظ الرابط: غير مصرح'), findsOneWidget);
      expect(bloc.events, isEmpty);
    });
  });
}
