import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_event.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_attendance_page.dart';
import 'package:rafiq_academy/shared/domain/attendance_service.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

class _AuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 't1',
      name: 'المعلم',
      role: AppRoles.teacher,
      isActive: true,
      createdAt: DateTime(2026),
    ),
  );

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _TeacherBloc extends Fake implements TeacherBloc {
  _TeacherBloc(this._state);

  TeacherState _state;
  final _controller = StreamController<TeacherState>.broadcast();
  final events = <TeacherEvent>[];

  @override
  TeacherState get state => _state;

  @override
  Stream<TeacherState> get stream => _controller.stream;

  @override
  void add(TeacherEvent event) => events.add(event);

  @override
  Future<void> close() => _controller.close();
}

Future<(_AuthBloc, _TeacherBloc)> _pump(
  WidgetTester tester,
  TeacherState state,
) async {
  await sl.reset();
  sl.registerSingleton<AttendanceService>(const AttendanceService());
  final auth = _AuthBloc();
  final teacher = _TeacherBloc(state);
  addTearDown(() async {
    await auth.close();
    await teacher.close();
    await sl.reset();
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocaleConfig.locale,
      supportedLocales: AppLocaleConfig.supportedLocales,
      localizationsDelegates: AppLocaleConfig.localizationsDelegates,
      theme: AppTheme.theme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<TeacherBloc>.value(value: teacher),
        ],
        child: const TeacherAttendancePage(halaqaId: 'h1', embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (auth, teacher);
}

void main() {
  testWidgets('empty roster shows honest empty copy', (tester) async {
    await _pump(
      tester,
      const TeacherState(
        studentsStatus: SectionStatus.loaded,
        studentsHalaqaId: 'h1',
        students: [],
        dayAttendanceStatus: SectionStatus.loaded,
      ),
    );

    expect(find.text('لا يوجد طلاب في هذه الحلقة'), findsOneWidget);
    expect(find.text('حفظ الحضور'), findsNothing);
  });

  testWidgets('students load error shows retry', (tester) async {
    final harness = await _pump(
      tester,
      const TeacherState(
        studentsStatus: SectionStatus.error,
        studentsError: 'تعذر تحميل الطلاب',
        studentsHalaqaId: 'h1',
        dayAttendanceStatus: SectionStatus.loaded,
      ),
    );

    expect(find.byType(AppErrorWidget), findsOneWidget);
    expect(find.textContaining('تعذر تحميل الطلاب'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(
      harness.$2.events.whereType<LoadHalaqaStudentsEvent>(),
      isNotEmpty,
    );
  });

  testWidgets('loaded roster shows save CTA disabled until marks complete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      TeacherState(
        studentsStatus: SectionStatus.loaded,
        studentsHalaqaId: 'h1',
        students: const [
          HalaqaStudentSummaryEntity(uid: 's1', name: 'أحمد'),
        ],
        dayAttendanceStatus: SectionStatus.loaded,
        dayAttendanceDate: DateTime(2026, 11, 20),
        pendingAbsenceRequestsStatus: SectionStatus.loaded,
        pendingAbsenceRequestsHalaqaId: 'h1',
        pendingAbsenceRequests: const [],
      ),
    );

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('حفظ الحضور'), findsOneWidget);
    final button = tester.widget<AppButton>(find.byType(AppButton).last);
    expect(button.onPressed, isNull);
  });
}
