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
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_state.dart';
import 'package:rafiq_academy/features/supervisor/presentation/pages/supervisor_halaqa_detail_page.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

import '../../support/fake_halaqa_meeting_link_repository.dart';

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

const _halaqa = HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: ['s1'],
  schedule: [],
  status: 'active',
);

Future<_FakeSupervisorBloc> _pump(
  WidgetTester tester, {
  required FakeHalaqaMeetingLinkRepository links,
  required _FakeOpsRepo repo,
  bool allowAdd = kSupervisorMeetingLinkAddEnabled,
}) async {
  await sl.reset();
  sl.registerFactory<SetHalaqaMeetingLinkUseCase>(
    () => SetHalaqaMeetingLinkUseCase(repo),
  );
  registerFakeMeetingLinks(links);
  final bloc = _FakeSupervisorBloc(
    SupervisorState.initial().copyWith(halaqat: const [_halaqa]),
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _FakeAuthBloc()),
        BlocProvider<SupervisorBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: SupervisorHalaqaDetailPage(
          halaqaId: 'h1',
          allowMeetingLinkAdd: allowAdd,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  tearDown(() => sl.reset());

  group('B14 supervisor meeting link before the legacy strip', () {
    test('supervisor add is gated off by default', () {
      expect(kSupervisorMeetingLinkAddEnabled, isFalse);
    });

    testWidgets(
      'a missing canonical doc (a legacy value may exist) offers no add',
      (tester) async {
        final repo = _FakeOpsRepo();
        final links = FakeHalaqaMeetingLinkRepository();
        await _pump(tester, links: links, repo: repo);
        expect(links.reads, ['h1']);
        expect(find.text('لم يُضبط رابط الاجتماع بعد'), findsOneWidget);
        expect(
          find.text('إضافة الرابط متاحة للمسؤول حاليًا؛ تواصل معه لضبطه.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
        expect(repo.calls, isEmpty);
      },
    );

    testWidgets('valid, invalid, denied and failed states never offer add', (
      tester,
    ) async {
      final cases = <FakeHalaqaMeetingLinkRepository>[
        FakeHalaqaMeetingLinkRepository({'h1': 'https://meet.example.com/a'}),
        FakeHalaqaMeetingLinkRepository({'h1': ''}),
        FakeHalaqaMeetingLinkRepository({'h1': 'http://meet.example.com/x'}),
        FakeHalaqaMeetingLinkRepository()
          ..failure = const MeetingLinkAccessDeniedFailure(),
        FakeHalaqaMeetingLinkRepository()..failure = const NetworkFailure(),
      ];
      for (final links in cases) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, links: links, repo: _FakeOpsRepo(), allowAdd: true);
        expect(links.reads, ['h1']);
        expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
      }
    });
  });

  group('B14 supervisor meeting link (add-only, gate on)', () {
    testWidgets('adds a link when no document exists and re-reads it', (
      tester,
    ) async {
      final repo = _FakeOpsRepo();
      final links = FakeHalaqaMeetingLinkRepository();
      final bloc = await _pump(
        tester,
        links: links,
        repo: repo,
        allowAdd: true,
      );
      expect(links.reads, ['h1']);
      expect(find.text('لم يُضبط رابط الاجتماع بعد'), findsOneWidget);

      await tester.tap(find.byKey(const Key('supervisorAddMeetingLink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meetingLinkClear')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        'https://meet.example.com/new',
      );
      links.links['h1'] = 'https://meet.example.com/new';
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();

      expect(repo.calls, ['h1:https://meet.example.com/new:false']);
      expect(find.text('تم حفظ رابط الاجتماع'), findsOneWidget);
      expect(bloc.events.whereType<LoadSupervisedHalaqatEvent>(), hasLength(1));
      expect(links.reads, ['h1', 'h1']);
      expect(find.text('رابط الاجتماع مضبوط'), findsOneWidget);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
    });

    testWidgets('an existing link is read-only for the supervisor', (
      tester,
    ) async {
      final repo = _FakeOpsRepo();
      await _pump(
        tester,
        links: FakeHalaqaMeetingLinkRepository({
          'h1': 'https://meet.example.com/a',
        }),
        repo: repo,
      );
      expect(find.text('رابط الاجتماع مضبوط'), findsOneWidget);
      expect(find.text('https://meet.example.com/a'), findsOneWidget);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('an invalid stored link is never shown and cannot be added', (
      tester,
    ) async {
      await _pump(
        tester,
        links: FakeHalaqaMeetingLinkRepository({
          'h1': 'http://meet.example.com/bad',
        }),
        repo: _FakeOpsRepo(),
      );
      expect(find.text('رابط الاجتماع المحفوظ غير صالح'), findsOneWidget);
      expect(find.text('http://meet.example.com/bad'), findsNothing);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
    });

    testWidgets('permission denied shows its own message, no add', (
      tester,
    ) async {
      await _pump(
        tester,
        links: FakeHalaqaMeetingLinkRepository()
          ..failure = const MeetingLinkAccessDeniedFailure(),
        repo: _FakeOpsRepo(),
      );
      expect(find.text('لا تملك صلاحية عرض رابط الاجتماع'), findsOneWidget);
      expect(find.text('تعذر تحميل رابط الاجتماع'), findsNothing);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
      expect(find.byKey(const Key('supervisorMeetingLinkRetry')), findsNothing);
    });

    testWidgets('a load failure offers retry and never offers add', (
      tester,
    ) async {
      final links = FakeHalaqaMeetingLinkRepository()
        ..failure = const NetworkFailure();
      await _pump(tester, links: links, repo: _FakeOpsRepo());
      expect(find.text('تعذر تحميل رابط الاجتماع'), findsOneWidget);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);

      links.failure = null;
      await tester.tap(find.byKey(const Key('supervisorMeetingLinkRetry')));
      await tester.pumpAndSettle();
      expect(links.reads, ['h1', 'h1']);
      expect(find.text('لم يُضبط رابط الاجتماع بعد'), findsOneWidget);
      expect(find.byKey(const Key('supervisorAddMeetingLink')), findsNothing);
    });

    testWidgets('a server refusal is shown and nothing reloads', (
      tester,
    ) async {
      final repo = _FakeOpsRepo()..failure = const ServerFailure('غير مصرح');
      final links = FakeHalaqaMeetingLinkRepository();
      final bloc = await _pump(
        tester,
        links: links,
        repo: repo,
        allowAdd: true,
      );
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
      expect(links.reads, ['h1']);
    });
  });
}
