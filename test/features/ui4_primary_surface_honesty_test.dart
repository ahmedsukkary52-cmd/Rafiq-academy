import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_home_page.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_management_tab.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_settings_tab.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/auth/presentation/pages/login_page.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_event.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_excuses_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/excuses/teacher_excuses_history_skeleton.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_empty_state.dart';
import 'package:rafiq_academy/shared/widgets/app_status_chip.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

HalaqaEntity _halaqa({String id = 'h1', String name = 'حلقة الفجر'}) =>
    HalaqaEntity(
      id: id,
      name: name,
      teacherId: 't1',
      supervisorId: 'sup1',
      studentIds: const ['s1'],
      schedule: const [],
      meetingLink: '',
      status: 'active',
    );

AbsenceRequestEntity _request({
  String id = 'req1',
  String studentId = 's1',
  String reason = 'ظرف عائلي',
}) => AbsenceRequestEntity(
  id: id,
  studentId: studentId,
  halaqaId: 'h1',
  requestedBy: 'parent1',
  date: DateTime(2026, 9, 20),
  reason: reason,
  status: AbsenceRequestStatus.pending,
);

UserEntity _teacherUser() => UserEntity(
  uid: 't1',
  name: 'محمد',
  role: 'teacher',
  email: 't@example.com',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

class _FakeAuthBloc extends Fake implements AuthBloc {
  _FakeAuthBloc(this._state);

  final AuthState _state;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class _FakeTeacherBloc extends Fake implements TeacherBloc {
  _FakeTeacherBloc(this._state);

  TeacherState _state;
  final _controller = StreamController<TeacherState>.broadcast();
  final List<TeacherEvent> captured = [];

  @override
  TeacherState get state => _state;

  @override
  Stream<TeacherState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(TeacherEvent event) {
    captured.add(event);
  }

  void emitState(TeacherState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

Widget _wrapExcuses({
  required AuthState authState,
  required TeacherState teacherState,
  _FakeTeacherBloc? teacherBloc,
}) {
  final auth = _FakeAuthBloc(authState);
  final teacher = teacherBloc ?? _FakeTeacherBloc(teacherState);
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<TeacherBloc>.value(value: teacher),
      ],
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: TeacherExcusesPage(),
      ),
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UI-4 teacherAbsenceStudentTitle', () {
    test('uses roster name when available', () {
      const students = [
        HalaqaStudentSummaryEntity(
          uid: 's1',
          name: 'أحمد',
          level: 1,
          attendancePercent: 0,
          overallProgressPercent: 0,
          todayAttendance: AttendanceStatus.absent,
          isAtRisk: false,
        ),
      ];
      expect(
        teacherAbsenceStudentTitle(studentId: 's1', students: students),
        'أحمد',
      );
    });

    test('falls back when student is unknown', () {
      expect(
        teacherAbsenceStudentTitle(studentId: 'missing', students: const []),
        'طالب',
      );
    });
  });

  group('UI-4 teacherAbsenceStatusTone', () {
    test('maps statuses to visual tones', () {
      expect(
        teacherAbsenceStatusTone(AbsenceRequestStatus.pending),
        AppStatusTone.warning,
      );
      expect(
        teacherAbsenceStatusTone(AbsenceRequestStatus.approved),
        AppStatusTone.success,
      );
      expect(
        teacherAbsenceStatusTone(AbsenceRequestStatus.rejected),
        AppStatusTone.error,
      );
    });
  });

  group('UI-4 TeacherExcusesPage', () {
    testWidgets('loading shows skeleton', (tester) async {
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: TeacherState(
            halaqatStatus: SectionStatus.loaded,
            halaqat: [_halaqa()],
            pendingAbsenceRequestsStatus: SectionStatus.loading,
            pendingAbsenceRequestsHalaqaId: 'h1',
            pendingAbsenceRequestsDate: DateTime.now(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TeacherExcusesHistorySkeleton), findsOneWidget);
      expect(find.text('+ طلب جديد'), findsNothing);
      expect(find.text('إرسال'), findsNothing);
    });

    testWidgets('empty shows truthful Arabic empty state', (tester) async {
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: TeacherState(
            halaqatStatus: SectionStatus.loaded,
            halaqat: [_halaqa()],
            pendingAbsenceRequestsStatus: SectionStatus.loaded,
            pendingAbsenceRequests: const [],
            pendingAbsenceRequestsHalaqaId: 'h1',
            pendingAbsenceRequestsDate: DateTime.now(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('لا توجد طلبات معلّقة'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);
    });

    testWidgets('error shows message and retry affordance', (tester) async {
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: TeacherState(
            halaqatStatus: SectionStatus.loaded,
            halaqat: [_halaqa()],
            pendingAbsenceRequestsStatus: SectionStatus.error,
            pendingAbsenceRequestsError: 'فشل التحميل',
            pendingAbsenceRequestsHalaqaId: 'h1',
            pendingAbsenceRequestsDate: DateTime.now(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('فشل التحميل'), findsOneWidget);
      expect(find.byType(AppErrorWidget), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('success renders pending requests and approve dispatches', (
      tester,
    ) async {
      final bloc = _FakeTeacherBloc(
        TeacherState(
          halaqatStatus: SectionStatus.loaded,
          halaqat: [_halaqa()],
          students: const [
            HalaqaStudentSummaryEntity(
              uid: 's1',
              name: 'أحمد',
              level: 1,
              attendancePercent: 0,
              overallProgressPercent: 0,
              todayAttendance: AttendanceStatus.absent,
              isAtRisk: false,
            ),
          ],
          pendingAbsenceRequestsStatus: SectionStatus.loaded,
          pendingAbsenceRequests: [_request()],
          pendingAbsenceRequestsHalaqaId: 'h1',
          pendingAbsenceRequestsDate: DateTime.now(),
        ),
      );
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: bloc.state,
          teacherBloc: bloc,
        ),
      );
      await tester.pump();

      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('ظرف عائلي'), findsOneWidget);
      expect(find.text('قبول'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);

      await tester.tap(find.text('قبول'));
      await tester.pump();

      final review = bloc.captured
          .whereType<ReviewAbsenceRequestEvent>()
          .single;
      expect(review.requestId, 'req1');
      expect(review.halaqaId, 'h1');
      expect(review.teacherId, 't1');
      expect(review.decision, AbsenceRequestStatus.approved);
    });

    testWidgets('reject dispatches ReviewAbsenceRequestEvent', (tester) async {
      final bloc = _FakeTeacherBloc(
        TeacherState(
          halaqatStatus: SectionStatus.loaded,
          halaqat: [_halaqa()],
          pendingAbsenceRequestsStatus: SectionStatus.loaded,
          pendingAbsenceRequests: [_request()],
          pendingAbsenceRequestsHalaqaId: 'h1',
          pendingAbsenceRequestsDate: DateTime.now(),
        ),
      );
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: bloc.state,
          teacherBloc: bloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('رفض'));
      await tester.pump();

      final review = bloc.captured
          .whereType<ReviewAbsenceRequestEvent>()
          .single;
      expect(review.decision, AbsenceRequestStatus.rejected);
    });

    testWidgets('explains parent-only review without self-excuse submit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapExcuses(
          authState: AuthAuthenticated(_teacherUser()),
          teacherState: TeacherState(
            halaqatStatus: SectionStatus.loaded,
            halaqat: [_halaqa()],
            pendingAbsenceRequestsStatus: SectionStatus.loaded,
            pendingAbsenceRequests: const [],
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('أولياء الأمور'), findsOneWidget);
      expect(find.textContaining('اعتذار ذاتي'), findsOneWidget);
      expect(find.text('+ طلب جديد'), findsNothing);
      expect(find.text('إرسال'), findsNothing);
    });
  });

  group('UI-4 AdminHomePage honesty', () {
    testWidgets('P0-02 operational hub without Coming Soon', (tester) async {
      await tester.pumpWidget(_wrap(const AdminManagementTab()));
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.text('واجهة الإدارة غير مفعّلة بعد'), findsNothing);
      for (final label in AdminHomePage.actionLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('settings tab exposes a real logout action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlocProvider<AuthBloc>.value(
            value: _FakeAuthBloc(const AuthUnauthenticated()),
            child: const AdminSettingsTab(),
          ),
        ),
      );
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });

  group('UI-4 password recovery honesty', () {
    testWidgets('login offers a real recovery CTA, no deferred copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          theme: AppTheme.theme,
          home: BlocProvider<AuthBloc>.value(
            value: _FakeAuthBloc(const AuthUnauthenticated()),
            child: const LoginPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('استعادة كلمة المرور غير متاحة حالياً'), findsNothing);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.textContaining('قريب'), findsNothing);
    });
  });
}
