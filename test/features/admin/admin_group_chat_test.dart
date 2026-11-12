import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/communication_settings_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/ensure_admin_internal_chat_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_academy_stats_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_academy_student_roster_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_admin_directory_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_all_teachers_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_complaints_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_financial_summary_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_payments_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/get_teacher_activity_log_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/grant_admin_reward_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/registration_request_usecases.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/respond_to_complaint_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/send_broadcast_notification_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/toggle_account_status_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_complaint_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_performance_usecase.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_quota_usecase.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_internal_chat_page.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_management_tab.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

import '../../support/fake_callables.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GroupRepo extends Fake implements AdminRepository {
  final results = <Either<Failure, String>>[];
  final askedFor = <String>[];

  @override
  Future<Either<Failure, String>> ensureAdminInternalChat({
    required String adminUid,
  }) async {
    askedFor.add(adminUid);
    return results.removeAt(0);
  }
}

AdminBloc _adminBloc(AdminRepository r) => AdminBloc(
  getAcademyStats: GetAcademyStatsUseCase(r),
  getFinancialSummary: GetFinancialSummaryUseCase(r),
  getPayments: GetPaymentsUseCase(r),
  getComplaints: GetComplaintsUseCase(r),
  approveNewStudent: ApproveNewStudentUseCase(r),
  toggleAccountStatus: ToggleAccountStatusUseCase(r),
  respondToComplaint: RespondToComplaintUseCase(r),
  sendBroadcastNotification: SendBroadcastNotificationUseCase(r),
  getAllTeachers: GetAllTeachersUseCase(r),
  updateTeacherPerformance: UpdateTeacherPerformanceUseCase(r),
  updateTeacherQuota: UpdateTeacherQuotaUseCase(r),
  getTeacherActivityLog: GetTeacherActivityLogUseCase(r),
  getAcademyStudentRoster: GetAcademyStudentRosterUseCase(r),
  getRegistrationRequests: GetRegistrationRequestsUseCase(r),
  rejectRegistrationRequest: RejectRegistrationRequestUseCase(r),
  approveRegistrationRequest: ApproveRegistrationRequestUseCase(r),
  getAllHalaqat: GetAllHalaqatUseCase(r),
  getAllSupervisors: GetAllSupervisorsUseCase(r),
  updateComplaint: UpdateComplaintUseCase(r),
  getCommunicationSettings: GetCommunicationSettingsUseCase(r),
  saveCommunicationSettings: SaveCommunicationSettingsUseCase(r),
  grantAdminReward: GrantAdminRewardUseCase(r),
  ensureAdminInternalChat: EnsureAdminInternalChatUseCase(r),
);

final _admin = UserEntity(
  uid: 'admin1',
  name: 'مدير',
  role: 'admin',
  isActive: true,
  createdAt: DateTime(2026),
);

/// The bootstrap skeleton animates forever, so pumpAndSettle never returns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

AdminRemoteDatasourceImpl _datasource(FakeFunctions functions) =>
    AdminRemoteDatasourceImpl(
      firestore: UnusedFirestore(),
      functions: functions,
    );

void main() {
  group('ensureAdminInternalChat datasource', () {
    test('asks the backend callable and sends no membership', () async {
      final functions = FakeFunctions()
        ..handlers['ensureAdminGroupConversation'] = (_) => {
          'conversationId': 'admin_internal_group',
          'action': 'create',
          'participantCount': 2,
        };
      final id = await _datasource(
        functions,
      ).ensureAdminInternalChat(adminUid: 'admin1');

      expect(id, 'admin_internal_group');
      expect(functions.calledNames, ['ensureAdminGroupConversation']);
      expect(functions.payloadOf('ensureAdminGroupConversation'), isEmpty);
    });

    test('maps server errors to Arabic messages without raw codes', () async {
      for (final code in [
        'permission-denied',
        'unauthenticated',
        'failed-precondition',
        'unavailable',
        'internal',
      ]) {
        final functions = FakeFunctions()
          ..handlers['ensureAdminGroupConversation'] = (_) =>
              throw FakeFunctionsError(code, 'Backend feature is disabled');
        await expectLater(
          _datasource(functions).ensureAdminInternalChat(adminUid: 'a'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.message, 'message', isNot(contains(code)))
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('Backend')),
                ),
          ),
          reason: code,
        );
      }
      expect(
        adminGroupErrorMessage('permission-denied'),
        'مجموعة الإدارة متاحة للمدير النشط فقط',
      );
    });

    test('a malformed response is an error, not an empty room id', () async {
      final functions = FakeFunctions()
        ..handlers['ensureAdminGroupConversation'] = (_) => {'action': 'noop'};
      await expectLater(
        _datasource(functions).ensureAdminInternalChat(adminUid: 'a'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('AdminInternalChatPage', () {
    Future<GoRouter> pumpPage(
      WidgetTester tester,
      AdminBloc bloc,
      AuthState auth,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.adminInternalNotes,
        routes: [
          GoRoute(
            path: AppRoutes.adminInternalNotes,
            builder: (_, __) => const AdminInternalChatPage(),
          ),
          GoRoute(
            path: '${AppRoutes.admin}/chat/:id',
            builder: (_, s) => Text('room:${s.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: _AuthBlocStub(auth)),
            BlocProvider<AdminBloc>.value(value: bloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      return router;
    }

    testWidgets('opens the backend group room on success', (tester) async {
      final repo = _GroupRepo()..results.add(const Right('admin_internal_group'));
      final bloc = _adminBloc(repo);
      await pumpPage(tester, bloc, AuthAuthenticated(_admin));
      await _settle(tester);

      expect(repo.askedFor, ['admin1']);
      expect(find.text('room:admin_internal_group'), findsOneWidget);
    });

    testWidgets('a denial shows a clear error with retry instead of an '
        'endless skeleton', (tester) async {
      final repo = _GroupRepo()
        ..results.addAll(const [
          Left(ServerFailure('مجموعة الإدارة متاحة للمدير النشط فقط')),
          Right('admin_internal_group'),
        ]);
      final bloc = _adminBloc(repo);
      await pumpPage(tester, bloc, AuthAuthenticated(_admin));
      await _settle(tester);

      expect(find.byKey(const Key('admin-group-error')), findsOneWidget);
      expect(
        find.text('مجموعة الإدارة متاحة للمدير النشط فقط'),
        findsOneWidget,
      );
      expect(find.textContaining('room:'), findsNothing);

      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);
      expect(repo.askedFor, ['admin1', 'admin1']);
      expect(find.text('room:admin_internal_group'), findsOneWidget);
    });

    testWidgets('signed out: no backend call and an explanatory message', (
      tester,
    ) async {
      final repo = _GroupRepo();
      final bloc = _adminBloc(repo);
      await pumpPage(tester, bloc, const AuthUnauthenticated());
      await _settle(tester);

      expect(repo.askedFor, isEmpty);
      expect(find.byKey(const Key('admin-group-error')), findsOneWidget);
    });
  });

  testWidgets('the Admin hub offers a visible entry to the admin group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AdminManagementTab()));
    await tester.pump();

    expect(find.text('مجموعة الإدارة'), findsOneWidget);
    expect(
      AdminManagementTab.hubRoutes,
      contains(AppRoutes.adminInternalNotes),
    );
  });

  test('the admin group is a group but never an editable custom group', () {
    const c = ConversationEntity(
      id: 'admin_internal_group',
      participants: [],
      unreadCount: 0,
      kind: ConversationKinds.adminGroup,
      title: 'مجموعة الإدارة',
    );
    expect(ConversationKinds.adminGroup, 'admin_group');
    expect(c.isGroup, isTrue);
    expect(c.isCustomGroup, isFalse);
    expect(c.displayTitle('anyone'), 'مجموعة الإدارة');
  });

  test('Flutter never writes the admin group membership itself', () {
    final page = File(
      'lib/features/admin/presentation/pages/admin_internal_chat_page.dart',
    ).readAsStringSync();
    final datasource = File(
      'lib/features/admin/data/datasources/admin_remote_datasource_impl.dart',
    ).readAsStringSync();
    final ensure = datasource.substring(
      datasource.indexOf('Future<String> ensureAdminInternalChat'),
    );
    for (final src in [page, ensure]) {
      expect(src, isNot(contains('participantIds')));
      expect(src, isNot(contains("collection('conversations')")));
    }
  });

  test('no client-side writer of the admin group remains in lib', () {
    expect(
      File('lib/shared/data/admin_internal_chat_firestore.dart').existsSync(),
      isFalse,
    );
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('admin_internal_group'))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
