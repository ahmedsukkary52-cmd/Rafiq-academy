import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/homework/domain/entities/homework_entity.dart';
import 'package:rafiq_academy/features/homework/presentation/bloc/homework_bloc.dart';
import 'package:rafiq_academy/features/homework/presentation/pages/student_homework_page.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeworkBlocStub extends Cubit<HomeworkState> implements HomeworkBloc {
  _HomeworkBlocStub() : super(const HomeworkState());

  final events = <HomeworkEvent>[];

  @override
  void add(HomeworkEvent event) => events.add(event);

  void push(HomeworkState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _student = UserEntity(
  uid: 's1',
  name: 'أحمد',
  role: AppRoles.student,
  isActive: true,
  createdAt: DateTime(2026),
);

final _homework = HomeworkEntity(
  id: 'hw1',
  title: 'واجب الأسبوع',
  dueAt: DateTime.now().add(const Duration(days: 2)),
  studentId: 's1',
  halaqaId: 'h1',
  tasks: const [
    HomeworkTaskEntity(
      id: 't1',
      title: 'قراءة: سورة الملك',
      points: 20,
      isCompleted: false,
      kind: HomeworkTaskKind.reading,
    ),
    HomeworkTaskEntity(
      id: 't3',
      title: 'تسميع سورة الملك',
      points: 30,
      isCompleted: false,
      kind: HomeworkTaskKind.recitation,
    ),
  ],
);

late _HomeworkBlocStub _bloc;

Future<void> _pump(WidgetTester tester, {AuthState? auth}) async {
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _AuthBlocStub(auth ?? AuthAuthenticated(_student)),
      child: const MaterialApp(home: StudentHomeworkPage()),
    ),
  );
  await tester.pump();
}

Future<void> _pumpLoaded(WidgetTester tester) async {
  await _pump(tester);
  _bloc.push(
    HomeworkState(
      status: SectionStatus.loaded,
      studentId: 's1',
      homework: _homework,
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerFactory<HomeworkBloc>(() => _bloc = _HomeworkBlocStub());
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('loads homework for the signed-in uid', (tester) async {
    await _pump(tester);
    expect(_bloc.events, [const LoadHomeworkEvent('s1')]);
  });

  testWidgets('signed-out users load with an empty uid', (tester) async {
    await _pump(tester, auth: const AuthUnauthenticated());
    expect(_bloc.events, [const LoadHomeworkEvent('')]);
  });

  testWidgets('a recitation task is display-only: no audio-send entry, '
      'dialog, or toggle', (tester) async {
    expect(AppCapabilities.audioUploadsEnabled, isFalse);
    await _pumpLoaded(tester);

    final task = find.text('تسميع سورة الملك');
    await tester.ensureVisible(task);
    expect(find.text('غير مطلوب لإنهاء الواجب'), findsOneWidget);

    await tester.tap(task);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('سيتوفر'), findsNothing);
    expect(find.textContaining('التسجيل الصوتي'), findsNothing);
    expect(find.text('مؤجل'), findsNothing);
    expect(_bloc.events, [const LoadHomeworkEvent('s1')]);
  });

  testWidgets('non-recitation tasks still toggle', (tester) async {
    await _pumpLoaded(tester);

    final task = find.text('قراءة: سورة الملك');
    await tester.ensureVisible(task);
    await tester.tap(task);
    await tester.pump();

    expect(_bloc.events, [
      const LoadHomeworkEvent('s1'),
      const ToggleTaskEvent('t1'),
    ]);
  });
}
