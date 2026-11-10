import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/class_session_entity.dart';
import 'package:rafiq_academy/features/schedule/presentation/bloc/schedule_bloc.dart';
import 'package:rafiq_academy/features/schedule/presentation/pages/student_schedule_page.dart';
import 'package:rafiq_academy/shared/domain/current_student_profile.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _ScheduleBlocStub extends Cubit<ScheduleState> implements ScheduleBloc {
  _ScheduleBlocStub() : super(const ScheduleState());

  final events = <ScheduleEvent>[];

  @override
  void add(ScheduleEvent event) => events.add(event);

  void push(ScheduleState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements CurrentStudentProfile {
  _Profile({this.halaqaId});

  @override
  String? name;

  @override
  String? halaqaId;
}

class _MeetingLinkRepository implements HalaqaMeetingLinkRepository {
  final requested = <String>[];

  @override
  Future<Either<Failure, HalaqaMeetingLink?>> getMeetingLink(
    String halaqaId,
  ) async {
    requested.add(halaqaId);
    return const Right(null);
  }
}

final _session = ClassSessionEntity(
  id: 'c1',
  title: 'حلقة الحفظ',
  type: ClassSessionType.memorization,
  startAt: DateTime.now().add(const Duration(hours: 1)),
  endAt: DateTime.now().add(const Duration(hours: 2)),
  teacherName: 'المعلم',
  status: ClassSessionStatus.upcoming,
);

late _ScheduleBlocStub _bloc;
late _MeetingLinkRepository _links;

Future<void> _pump(WidgetTester tester, _Profile profile) async {
  await tester.pumpWidget(
    MaterialApp(
      // The test font is wider than Arabic glyphs; keep fixed-width buttons
      // from overflowing.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(0.5)),
        child: child!,
      ),
      home: StudentSchedulePage(currentStudent: profile),
    ),
  );
  await tester.pump();
}

Future<void> _emit(WidgetTester tester, ScheduleState state) async {
  _bloc.push(state);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    await sl.reset();
    _links = _MeetingLinkRepository();
    sl.registerFactory<ScheduleBloc>(() => _bloc = _ScheduleBlocStub());
    sl.registerLazySingleton(() => GetHalaqaMeetingLinkUseCase(_links));
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('first load uses the trimmed profile halaqa id', (tester) async {
    await _pump(tester, _Profile(halaqaId: '  h1 '));
    expect(_bloc.events, [const LoadWeeklySessionsEvent('h1')]);
    expect(find.byType(AppErrorWidget), findsNothing);
  });

  testWidgets('missing profile halaqa loads with an empty id and shows the '
      'no-halaqa message', (tester) async {
    await _pump(tester, _Profile());
    expect(_bloc.events, [const LoadWeeklySessionsEvent('')]);

    await _emit(tester, const ScheduleState(status: SectionStatus.loaded));
    expect(find.textContaining('لم يتم ربطك بحلقة بعد'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('a profile loaded after opening shows the empty schedule and '
      'retry uses the new halaqa id', (tester) async {
    final profile = _Profile();
    await _pump(tester, profile);

    profile.halaqaId = ' h2 ';
    await _emit(tester, const ScheduleState(status: SectionStatus.loaded));
    expect(find.text('لا توجد مواعيد في جدول الحلقة حالياً'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(_bloc.events, [
      const LoadWeeklySessionsEvent(''),
      const LoadWeeklySessionsEvent('h2'),
    ]);
  });

  testWidgets('error retry reads the latest halaqa id', (tester) async {
    final profile = _Profile(halaqaId: 'h1');
    await _pump(tester, profile);

    profile.halaqaId = 'h9';
    await _emit(
      tester,
      const ScheduleState(status: SectionStatus.error, errorMessage: 'x'),
    );
    tester.widget<AppErrorWidget>(find.byType(AppErrorWidget)).onRetry!();
    expect(_bloc.events.last, const LoadWeeklySessionsEvent('h9'));
  });

  testWidgets('error retry falls back to the initial id when the profile '
      'no longer has one', (tester) async {
    final profile = _Profile(halaqaId: ' h1 ');
    await _pump(tester, profile);

    profile.halaqaId = null;
    await _emit(
      tester,
      const ScheduleState(status: SectionStatus.error, errorMessage: 'x'),
    );
    tester.widget<AppErrorWidget>(find.byType(AppErrorWidget)).onRetry!();
    expect(_bloc.events, [
      const LoadWeeklySessionsEvent('h1'),
      const LoadWeeklySessionsEvent('h1'),
    ]);
  });

  testWidgets('join passes the current halaqa id to the meeting lookup', (
    tester,
  ) async {
    final profile = _Profile(halaqaId: 'h1');
    await _pump(tester, profile);

    profile.halaqaId = ' h3 ';
    await _emit(
      tester,
      ScheduleState(status: SectionStatus.loaded, sessions: [_session]),
    );
    await tester.tap(find.text('انضم للحصة الآن'));
    await tester.pump();
    await tester.pump();
    expect(_links.requested, ['h3']);
  });
}
