import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/data/communication_settings_errors.dart';
import 'package:rafiq_academy/features/admin/domain/entities/communication_settings_entity.dart';
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
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_misc_pages.dart';

const _server = CommunicationSettingsEntity(
  autoReplyOutsideHours: false,
  broadcastsNeedApproval: false,
  maxFileSizeMb: 10,
  allowedFileTypes: 'PDF',
  conversationRetentionDays: 90,
);

/// Each load/save waits on a completer the test resolves explicitly.
class _SettingsRepo extends Fake implements AdminRepository {
  final List<Completer<Either<Failure, CommunicationSettingsEntity>>> loads =
      [];
  final List<CommunicationSettingsEntity> saved = [];
  final List<Completer<Either<Failure, Unit>>> saves = [];

  @override
  Future<Either<Failure, CommunicationSettingsEntity>>
  getCommunicationSettings() {
    final c = Completer<Either<Failure, CommunicationSettingsEntity>>();
    loads.add(c);
    return c.future;
  }

  @override
  Future<Either<Failure, Unit>> saveCommunicationSettings(
    CommunicationSettingsEntity settings,
  ) {
    saved.add(settings);
    final c = Completer<Either<Failure, Unit>>();
    saves.add(c);
    return c.future;
  }
}

AdminBloc _bloc(AdminRepository r) => AdminBloc(
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

Future<void> _pump(WidgetTester tester, AdminBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: const AdminCommunicationSettingsPage(),
      ),
    ),
  );
  await tester.pump();
}

final _save = find.byKey(const Key('communication-settings-save'));
final _loadError = find.byKey(const Key('communication-settings-load-error'));
final _autoReply = find.widgetWithText(
  SwitchListTile,
  'رد تلقائي خارج أوقات العمل',
);

bool _saveEnabled(WidgetTester tester) => tester
    .widget<ElevatedButton>(
      find.descendant(of: _save, matching: find.byType(ElevatedButton)),
    )
    .enabled;

const _loadFailure = Left<Failure, CommunicationSettingsEntity>(
  ServerFailure(kCommunicationSettingsLoadFailedMessage),
);

/// Awaiting a real Bloc's close() inside testWidgets never completes under
/// the fake clock, so it is started and pumped but not awaited.
Future<void> _close(WidgetTester tester, Bloc<Object?, Object?> bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

void main() {
  test('error mapping never exposes raw codes', () {
    for (final save in [true, false]) {
      for (final code in ['permission-denied', 'unavailable', 'internal']) {
        final m = communicationSettingsErrorMessage(code, save: save);
        expect(m, isNot(contains(code)));
      }
    }
    expect(
      communicationSettingsErrorMessage('unavailable', save: false),
      kCommunicationSettingsOfflineMessage,
    );
    expect(
      communicationSettingsErrorMessage('aborted', save: true),
      kCommunicationSettingsSaveFailedMessage,
    );
  });

  testWidgets('failed initial load shows retry and no savable form', (
    tester,
  ) async {
    final repo = _SettingsRepo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    expect(_save, findsNothing);

    repo.loads.single.complete(_loadFailure);
    await tester.pumpAndSettle();

    expect(_loadError, findsOneWidget);
    expect(find.text(kCommunicationSettingsLoadFailedMessage), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(_save, findsNothing);
    expect(_autoReply, findsNothing);
    await _close(tester, bloc);
  });

  testWidgets('settings from an earlier visit are not savable after a failed '
      'reload', (tester) async {
    final repo = _SettingsRepo();
    final bloc = _bloc(repo);
    bloc.add(const LoadCommunicationSettingsEvent());
    await tester.pump();
    repo.loads.single.complete(const Right(_server));
    await bloc.stream.firstWhere(
      (s) => s.communicationSettingsStatus == SectionStatus.loaded,
    );

    await _pump(tester, bloc);
    expect(_save, findsNothing, reason: 'stale form hidden while reloading');

    repo.loads.last.complete(_loadFailure);
    await tester.pumpAndSettle();
    expect(_loadError, findsOneWidget);
    expect(_save, findsNothing);
    expect(repo.saved, isEmpty);
    await _close(tester, bloc);
  });

  testWidgets('retry after a failed load shows the server values', (
    tester,
  ) async {
    final repo = _SettingsRepo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(_loadFailure);
    await tester.pumpAndSettle();

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(repo.loads, hasLength(2));
    expect(_loadError, findsNothing);

    repo.loads.last.complete(const Right(_server));
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);
    expect(tester.widget<SwitchListTile>(_autoReply).value, isFalse);
    expect(find.text('10 MB'), findsOneWidget);
    await _close(tester, bloc);
  });

  testWidgets('save sends the edits and confirms only after success', (
    tester,
  ) async {
    final repo = _SettingsRepo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(const Right(_server));
    await tester.pumpAndSettle();

    await tester.tap(_autoReply);
    await tester.pump();
    await tester.tap(_save);
    await tester.tap(_save, warnIfMissed: false);
    await tester.pump();
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.autoReplyOutsideHours, isTrue);
    expect(repo.saved.single.maxFileSizeMb, 10);
    expect(find.text('تم حفظ الإعدادات'), findsNothing);

    repo.saves.single.complete(const Right(unit));
    await tester.pump();
    await tester.pump();
    expect(find.text('تم حفظ الإعدادات'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_autoReply).value, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _close(tester, bloc);
  });

  testWidgets('failed save keeps the edits and a retry resends them', (
    tester,
  ) async {
    final repo = _SettingsRepo();
    final bloc = _bloc(repo);
    await _pump(tester, bloc);
    repo.loads.single.complete(const Right(_server));
    await tester.pumpAndSettle();

    await tester.tap(_autoReply);
    await tester.pump();
    await tester.tap(_save);
    await tester.pump();
    repo.saves.single.complete(
      const Left(ServerFailure(kCommunicationSettingsSaveFailedMessage)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(kCommunicationSettingsSaveFailedMessage), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_autoReply).value, isTrue);
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(_save);
    await tester.pump();
    expect(repo.saved, hasLength(2));
    expect(repo.saved.last, repo.saved.first);
    repo.saves.last.complete(const Right(unit));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _close(tester, bloc);
  });
}
