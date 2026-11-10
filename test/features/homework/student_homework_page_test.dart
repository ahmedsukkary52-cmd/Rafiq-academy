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
import 'package:rafiq_academy/features/student/presentation/pages/student_recitation_page.dart';
import 'package:rafiq_academy/shared/domain/current_student_profile.dart';

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

class _CountingProfile implements CurrentStudentProfile {
  int reads = 0;

  @override
  String? get name {
    reads++;
    return 'أحمد';
  }

  @override
  String? get halaqaId {
    reads++;
    return 'h1';
  }
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
      title: 'تسميع سورة الملك',
      points: 10,
      isCompleted: false,
      kind: HomeworkTaskKind.recitation,
    ),
  ],
);

late _HomeworkBlocStub _bloc;

Future<void> _pump(
  WidgetTester tester,
  CurrentStudentProfile profile, {
  AuthState? auth,
}) async {
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _AuthBlocStub(auth ?? AuthAuthenticated(_student)),
      child: MaterialApp(home: StudentHomeworkPage(currentStudent: profile)),
    ),
  );
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

  testWidgets('loads homework for the signed-in uid without reading the '
      'student profile', (tester) async {
    final profile = _CountingProfile();
    await _pump(tester, profile);
    expect(_bloc.events, [const LoadHomeworkEvent('s1')]);
    expect(profile.reads, 0);
  });

  testWidgets('signed-out users load with an empty uid', (tester) async {
    await _pump(tester, _CountingProfile(), auth: const AuthUnauthenticated());
    expect(_bloc.events, [const LoadHomeworkEvent('')]);
  });

  testWidgets('a deferred recitation task shows the info dialog without '
      'opening recitation or reading the profile', (tester) async {
    expect(AppCapabilities.audioUploadsEnabled, isFalse);
    final profile = _CountingProfile();
    await _pump(tester, profile);

    _bloc.push(
      HomeworkState(
        status: SectionStatus.loaded,
        studentId: 's1',
        homework: _homework,
      ),
    );
    await tester.pump();
    await tester.pump();

    final task = find.text('تسميع سورة الملك');
    await tester.ensureVisible(task);
    await tester.tap(task);
    await tester.pumpAndSettle();

    expect(find.text('التسميع الصوتي'), findsOneWidget);
    expect(find.byType(StudentRecitationPage), findsNothing);
    expect(profile.reads, 0);
    expect(_bloc.events, [const LoadHomeworkEvent('s1')]);
  });
}
