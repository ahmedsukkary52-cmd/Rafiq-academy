import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_halaqa_roster_entity.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/entities/academy_stats_entity.dart';

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
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';

class _Toggle extends Fake implements ToggleAccountStatusUseCase {
  _Toggle(this.result);
  Either<Failure, Unit> result;
  @override
  Future<Either<Failure, Unit>> call(ToggleAccountParams params) async =>
      result;
}

class _Roster extends Fake implements GetAcademyStudentRosterUseCase {
  _Roster(this.result);
  Either<Failure, List<AdminHalaqaRosterEntity>> result;
  @override
  Future<Either<Failure, List<AdminHalaqaRosterEntity>>> call(
    NoParams params,
  ) async => result;
}

class _UnusedStats extends Fake implements GetAcademyStatsUseCase {}

class _UnusedFinancial extends Fake implements GetFinancialSummaryUseCase {}

class _UnusedPayments extends Fake implements GetPaymentsUseCase {}

class _UnusedComplaints extends Fake implements GetComplaintsUseCase {}

class _UnusedApprove extends Fake implements ApproveNewStudentUseCase {}

class _UnusedRespond extends Fake implements RespondToComplaintUseCase {}

class _UnusedBroadcast extends Fake
    implements SendBroadcastNotificationUseCase {}

class _UnusedTeachers extends Fake implements GetAllTeachersUseCase {}

class _UnusedPerformance extends Fake
    implements UpdateTeacherPerformanceUseCase {}

class _UnusedQuota extends Fake implements UpdateTeacherQuotaUseCase {}

class _UnusedActivity extends Fake implements GetTeacherActivityLogUseCase {}

class _UnusedRegistration extends Fake
    implements GetRegistrationRequestsUseCase {}

class _UnusedReject extends Fake implements RejectRegistrationRequestUseCase {}

class _UnusedApproveRegistration extends Fake
    implements ApproveRegistrationRequestUseCase {}

class _UnusedHalaqat extends Fake implements GetAllHalaqatUseCase {}

class _UnusedSupervisors extends Fake implements GetAllSupervisorsUseCase {}

class _UnusedComplaintUpdate extends Fake implements UpdateComplaintUseCase {}

class _UnusedCommunicationGet extends Fake
    implements GetCommunicationSettingsUseCase {}

class _UnusedCommunicationSave extends Fake
    implements SaveCommunicationSettingsUseCase {}

class _UnusedReward extends Fake implements GrantAdminRewardUseCase {}

class _UnusedChat extends Fake implements EnsureAdminInternalChatUseCase {}

AdminBloc _bloc({
  required Either<Failure, Unit> toggle,
  required Either<Failure, List<AdminHalaqaRosterEntity>> roster,
}) => AdminBloc(
  getAcademyStats: _UnusedStats(),
  getFinancialSummary: _UnusedFinancial(),
  getPayments: _UnusedPayments(),
  getComplaints: _UnusedComplaints(),
  approveNewStudent: _UnusedApprove(),
  toggleAccountStatus: _Toggle(toggle),
  respondToComplaint: _UnusedRespond(),
  sendBroadcastNotification: _UnusedBroadcast(),
  getAllTeachers: _UnusedTeachers(),
  updateTeacherPerformance: _UnusedPerformance(),
  updateTeacherQuota: _UnusedQuota(),
  getTeacherActivityLog: _UnusedActivity(),
  getAcademyStudentRoster: _Roster(roster),
  getRegistrationRequests: _UnusedRegistration(),
  rejectRegistrationRequest: _UnusedReject(),
  approveRegistrationRequest: _UnusedApproveRegistration(),
  getAllHalaqat: _UnusedHalaqat(),
  getAllSupervisors: _UnusedSupervisors(),
  updateComplaint: _UnusedComplaintUpdate(),
  getCommunicationSettings: _UnusedCommunicationGet(),
  saveCommunicationSettings: _UnusedCommunicationSave(),
  grantAdminReward: _UnusedReward(),
  ensureAdminInternalChat: _UnusedChat(),
);

Future<AdminState> _run(AdminBloc bloc) async {
  final done = bloc.stream.firstWhere(
    (state) => state.toggleAccountStatus != SubmissionStatus.submitting,
  );
  bloc.add(const ToggleAccountStatusEvent(uid: 'uid', isActive: true));
  return done;
}

void main() {
  test('full success waits for roster refresh', () async {
    final bloc = _bloc(toggle: const Right(unit), roster: const Right([]));
    addTearDown(bloc.close);

    final state = await _run(bloc);

    expect(state.toggleAccountStatus, SubmissionStatus.success);
    expect(state.rosterStatus, SectionStatus.loaded);
  });

  test('callable success with roster failure is partial success', () async {
    final bloc = _bloc(
      toggle: const Right(unit),
      roster: Left(const NetworkFailure('Roster load failed')),
    );
    addTearDown(bloc.close);

    final state = await _run(bloc);

    expect(state.toggleAccountStatus, SubmissionStatus.success);
    expect(state.rosterStatus, SectionStatus.error);
    expect(state.rosterError, 'Roster load failed');
  });

  test('callable failure does not refresh the roster', () async {
    final bloc = _bloc(
      toggle: Left(const NetworkFailure('Network error')),
      roster: const Right([]),
    );
    addTearDown(bloc.close);

    final state = await _run(bloc);

    expect(state.toggleAccountStatus, SubmissionStatus.error);
    expect(state.toggleAccountError, 'Network error');
  });
}
