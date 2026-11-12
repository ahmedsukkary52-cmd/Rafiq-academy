import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/entities/academy_stats_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/complaint_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/financial_summary_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_dashboard_tab.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_state.dart';

class _FakeAdminBloc extends Fake implements AdminBloc {
  _FakeAdminBloc(this.state);

  @override
  AdminState state;

  @override
  Stream<AdminState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(AdminEvent event) {}

  @override
  Future<void> close() async {}
}

class _FakeAuthBloc extends Fake implements AuthBloc {
  @override
  AuthState get state => AuthInitial();

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {}
}

class _FakeNotificationsBloc extends Fake implements NotificationsBloc {
  @override
  NotificationsState get state => const NotificationsState();

  @override
  Stream<NotificationsState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(NotificationsEvent event) {}

  @override
  Future<void> close() async {}
}

Future<void> _pump(WidgetTester tester, AdminState state) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AdminBloc>.value(value: _FakeAdminBloc(state)),
            BlocProvider<AuthBloc>.value(value: _FakeAuthBloc()),
            BlocProvider<NotificationsBloc>.value(
              value: _FakeNotificationsBloc(),
            ),
          ],
          child: const Scaffold(body: AdminDashboardTab()),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _loaded = AdminState(
  statsStatus: SectionStatus.loaded,
  financialStatus: SectionStatus.loaded,
  complaintsStatus: SectionStatus.loaded,
  registrationStatus: SectionStatus.loaded,
);

void main() {
  testWidgets('failed registrations and complaints never read as empty', (
    tester,
  ) async {
    await _pump(
      tester,
      _loaded.copyWith(
        registrationStatus: SectionStatus.error,
        registrationError: 'تعذر تحميل طلبات التسجيل',
        complaintsStatus: SectionStatus.error,
        complaintsError: '[cloud_firestore/permission-denied] denied',
      ),
    );

    expect(find.text('لا توجد طلبات تسجيل بانتظار التعيين'), findsNothing);
    expect(find.text('لا توجد شكاوى مفتوحة حالياً'), findsNothing);
    expect(find.text('تعذر تحميل طلبات التسجيل'), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.text('كل شيء على ما يرام اليوم'), findsNothing);
    expect(find.text('تعذر تحميل بعض البيانات'), findsOneWidget);
  });

  testWidgets('genuinely empty sections keep their empty copy', (
    tester,
  ) async {
    await _pump(tester, _loaded);

    expect(find.text('لا توجد طلبات تسجيل بانتظار التعيين'), findsOneWidget);
    expect(find.text('لا توجد شكاوى مفتوحة حالياً'), findsOneWidget);
    expect(find.text('كل شيء على ما يرام اليوم'), findsOneWidget);
  });

  testWidgets('complaint badges show Arabic status, never the raw code', (
    tester,
  ) async {
    await _pump(
      tester,
      _loaded.copyWith(
        complaints: [
          ComplaintEntity(
            id: 'c1',
            senderId: 'p1',
            senderRole: 'parent',
            subject: 'موعد الحلقة',
            message: 'تغيير الموعد',
            status: ComplaintStatuses.inProgress,
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
      ),
    );

    expect(find.text('قيد المعالجة'), findsOneWidget);
    expect(find.text(ComplaintStatuses.inProgress), findsNothing);
  });

  testWidgets('four metric cards from live counts; no duplicate halaqat card', (
    tester,
  ) async {
    await _pump(
      tester,
      _loaded.copyWith(
        stats: const AcademyStatsEntity(
          totalStudents: 40,
          totalTeachers: 6,
          totalHalaqat: 5,
          totalSupervisors: 3,
          overallAttendancePercent: 0,
          totalVersesMemorizedThisMonth: 0,
        ),
        financialSummary: const FinancialSummaryEntity(
          totalRevenue: 1200,
          totalPending: 600,
          totalOverdue: 300,
          paidCount: 4,
          dueCount: 2,
          overdueCount: 1,
          awaitingReviewCount: 2,
        ),
      ),
    );

    expect(find.text('إجمالي الطلاب'), findsOneWidget);
    expect(find.text('إجمالي المشرفين'), findsOneWidget);
    expect(find.text('مدفوعات غير مسددة'), findsOneWidget);
    expect(find.text('المعلمون'), findsOneWidget);
    expect(find.text('حلقات نشطة'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('admin-stat-unpaid')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 للمراجعة'), findsOneWidget);
    expect(find.byKey(const Key('admin-health-warning')), findsOneWidget);
    expect(find.text('1 دفعة متأخرة'), findsOneWidget);
  });
}
