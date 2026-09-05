import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../../domain/usecases/communication_settings_usecases.dart';
import '../../domain/usecases/create_halaqa_usecase.dart';
import '../../domain/usecases/get_academy_student_roster_usecase.dart';
import '../../domain/usecases/get_admin_directory_usecases.dart';
import '../../domain/usecases/grant_admin_reward_usecase.dart';
import '../../domain/usecases/registration_request_usecases.dart';
import '../../domain/usecases/update_complaint_usecase.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/approve_new_student_usecase.dart';
import '../../domain/usecases/get_academy_stats_usecase.dart';
import '../../domain/usecases/get_all_teachers_usecase.dart';
import '../../domain/usecases/get_complaints_usecase.dart';
import '../../domain/usecases/get_financial_summary_usecase.dart';
import '../../domain/usecases/get_teacher_activity_log_usecase.dart';
import '../../domain/usecases/respond_to_complaint_usecase.dart';
import '../../domain/usecases/send_broadcast_notification_usecase.dart';
import '../../domain/usecases/toggle_account_status_usecase.dart';
import '../../domain/usecases/update_teacher_performance_usecase.dart';
import '../../domain/usecases/update_teacher_quota_usecase.dart';
import 'admin_event.dart';
import 'admin_state.dart';

/// Admin dashboard and management projections — stats, finance, complaints,
/// roster, registration, rewards, and communication settings.
///
/// **H1:** [ClearAdminSessionEvent] resets projections on logout.
@singleton
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final GetAcademyStatsUseCase getAcademyStats;
  final GetFinancialSummaryUseCase getFinancialSummary;
  final GetComplaintsUseCase getComplaints;
  final ApproveNewStudentUseCase approveNewStudent;
  final ToggleAccountStatusUseCase toggleAccountStatus;
  final RespondToComplaintUseCase respondToComplaint;
  final SendBroadcastNotificationUseCase sendBroadcastNotification;
  final GetAllTeachersUseCase getAllTeachers;
  final UpdateTeacherPerformanceUseCase updateTeacherPerformance;
  final UpdateTeacherQuotaUseCase updateTeacherQuota;
  final GetTeacherActivityLogUseCase getTeacherActivityLog;
  final GetAcademyStudentRosterUseCase getAcademyStudentRoster;
  final GetRegistrationRequestsUseCase getRegistrationRequests;
  final RejectRegistrationRequestUseCase rejectRegistrationRequest;
  final ApproveRegistrationRequestUseCase approveRegistrationRequest;
  final GetAllHalaqatUseCase getAllHalaqat;
  final GetAllSupervisorsUseCase getAllSupervisors;
  final UpdateComplaintUseCase updateComplaint;
  final GetCommunicationSettingsUseCase getCommunicationSettings;
  final SaveCommunicationSettingsUseCase saveCommunicationSettings;
  final GrantAdminRewardUseCase grantAdminReward;
  final CreateHalaqaUseCase createHalaqa;
  final EnsureAdminInternalChatUseCase ensureAdminInternalChat;

  AdminBloc({
    required this.getAcademyStats,
    required this.getFinancialSummary,
    required this.getComplaints,
    required this.approveNewStudent,
    required this.toggleAccountStatus,
    required this.respondToComplaint,
    required this.sendBroadcastNotification,
    required this.getAllTeachers,
    required this.updateTeacherPerformance,
    required this.updateTeacherQuota,
    required this.getTeacherActivityLog,
    required this.getAcademyStudentRoster,
    required this.getRegistrationRequests,
    required this.rejectRegistrationRequest,
    required this.approveRegistrationRequest,
    required this.getAllHalaqat,
    required this.getAllSupervisors,
    required this.updateComplaint,
    required this.getCommunicationSettings,
    required this.saveCommunicationSettings,
    required this.grantAdminReward,
    required this.createHalaqa,
    required this.ensureAdminInternalChat,
  }) : super(AdminState.initial()) {
    on<LoadAcademyStatsEvent>(_onLoadStats);
    on<LoadFinancialSummaryEvent>(_onLoadFinancialSummary);
    on<RefreshAdminDashboardEvent>(_onRefreshDashboard);
    on<LoadComplaintsEvent>(_onLoadComplaints);
    on<ApproveNewStudentEvent>(_onApproveStudent);
    on<ResetApproveStudentEvent>(_onResetApproveStudent);
    on<ToggleAccountStatusEvent>(_onToggleAccount);
    on<ResetToggleAccountEvent>(_onResetToggleAccount);
    on<RespondToComplaintEvent>(_onRespondToComplaint);
    on<ResetRespondComplaintEvent>(_onResetRespondComplaint);
    on<SendBroadcastNotificationEvent>(_onSendBroadcast);
    on<ResetBroadcastEvent>(_onResetBroadcast);
    on<LoadAllTeachersEvent>(_onLoadAllTeachers);
    on<UpdateTeacherPerformanceEvent>(_onUpdateTeacherPerformance);
    on<ResetUpdateTeacherPerformanceEvent>(_onResetUpdateTeacherPerformance);
    on<UpdateTeacherQuotaEvent>(_onUpdateTeacherQuota);
    on<ResetUpdateTeacherQuotaEvent>(_onResetUpdateTeacherQuota);
    on<LoadTeacherActivityLogEvent>(_onLoadTeacherActivityLog);
    on<LoadStudentRosterEvent>(_onLoadStudentRoster);
    on<LoadRegistrationRequestsEvent>(_onLoadRegistrationRequests);
    on<LoadAdminDirectoryEvent>(_onLoadAdminDirectory);
    on<RejectRegistrationRequestEvent>(_onRejectRegistration);
    on<ApproveRegistrationRequestEvent>(_onApproveRegistration);
    on<ResetRegistrationActionEvent>(_onResetRegistrationAction);
    on<UpdateComplaintEvent>(_onUpdateComplaint);
    on<ResetUpdateComplaintEvent>(_onResetUpdateComplaint);
    on<LoadCommunicationSettingsEvent>(_onLoadCommunicationSettings);
    on<SaveCommunicationSettingsEvent>(_onSaveCommunicationSettings);
    on<ResetCommunicationSettingsEvent>(_onResetCommunicationSettings);
    on<GrantAdminRewardEvent>(_onGrantReward);
    on<ResetGrantRewardEvent>(_onResetGrantReward);
    on<CreateHalaqaEvent>(_onCreateHalaqa);
    on<ResetCreateHalaqaEvent>(_onResetCreateHalaqa);
    on<EnsureAdminInternalChatEvent>(_onEnsureAdminInternalChat);
    on<ClearAdminSessionEvent>(_onClearSession);
  }

  void _onClearSession(ClearAdminSessionEvent event, Emitter<AdminState> emit) {
    emit(AdminState.initial());
  }

  // ══════════════════════════════════════════════════════════════════════
  // إحصائيات الأكاديمية
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadStats(
    LoadAcademyStatsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(statsStatus: SectionStatus.loading, statsError: null));

    final result = await getAcademyStats(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          statsStatus: SectionStatus.error,
          statsError: failure.message,
        ),
      ),
      (stats) =>
          emit(state.copyWith(statsStatus: SectionStatus.loaded, stats: stats)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // الملخص المالي
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadFinancialSummary(
    LoadFinancialSummaryEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        financialStatus: SectionStatus.loading,
        financialError: null,
      ),
    );

    final result = await getFinancialSummary(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          financialStatus: SectionStatus.error,
          financialError: failure.message,
        ),
      ),
      (summary) => emit(
        state.copyWith(
          financialStatus: SectionStatus.loaded,
          financialSummary: summary,
        ),
      ),
    );
  }

  /// تحميل الإحصائيات والملخص المالي والشكاوى مع بعض بالتوازي،
  /// لتسريع فتح لوحة الإدارة الرئيسية لأول مرة.
  Future<void> _onRefreshDashboard(
    RefreshAdminDashboardEvent event,
    Emitter<AdminState> emit,
  ) async {
    await Future.wait([
      _onLoadStats(const LoadAcademyStatsEvent(), emit),
      _onLoadFinancialSummary(const LoadFinancialSummaryEvent(), emit),
      _onLoadComplaints(const LoadComplaintsEvent(), emit),
      _onLoadRegistrationRequests(const LoadRegistrationRequestsEvent(), emit),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  // الشكاوى
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadComplaints(
    LoadComplaintsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        complaintsStatus: SectionStatus.loading,
        complaintsError: null,
      ),
    );

    final result = await getComplaints(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          complaintsStatus: SectionStatus.error,
          complaintsError: failure.message,
        ),
      ),
      (complaints) => emit(
        state.copyWith(
          complaintsStatus: SectionStatus.loaded,
          complaints: complaints,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // قبول طالب جديد
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onApproveStudent(
    ApproveNewStudentEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        approveStudentStatus: SubmissionStatus.submitting,
        approveStudentError: null,
      ),
    );

    final result = await approveNewStudent(
      ApproveStudentParams(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          approveStudentStatus: SubmissionStatus.error,
          approveStudentError: failure.message,
        ),
      ),
      (_) =>
          emit(state.copyWith(approveStudentStatus: SubmissionStatus.success)),
    );
  }

  void _onResetApproveStudent(
    ResetApproveStudentEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        approveStudentStatus: SubmissionStatus.idle,
        approveStudentError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تفعيل / تعطيل حساب
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onToggleAccount(
    ToggleAccountStatusEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        toggleAccountStatus: SubmissionStatus.submitting,
        toggleAccountError: null,
      ),
    );

    final result = await toggleAccountStatus(
      ToggleAccountParams(uid: event.uid, isActive: event.isActive),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          toggleAccountStatus: SubmissionStatus.error,
          toggleAccountError: failure.message,
        ),
      ),
      (_) =>
          emit(state.copyWith(toggleAccountStatus: SubmissionStatus.success)),
    );
  }

  void _onResetToggleAccount(
    ResetToggleAccountEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        toggleAccountStatus: SubmissionStatus.idle,
        toggleAccountError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // الرد على شكوى
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onRespondToComplaint(
    RespondToComplaintEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        respondComplaintStatus: SubmissionStatus.submitting,
        respondComplaintError: null,
      ),
    );

    final result = await respondToComplaint(
      RespondComplaintParams(
        complaintId: event.complaintId,
        response: event.response,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          respondComplaintStatus: SubmissionStatus.error,
          respondComplaintError: failure.message,
        ),
      ),
      (_) {
        // بنحدّث حالة الشكوى محلياً لـ "resolved" بدل ما نعمل reload
        // كامل لقائمة الشكاوى كلها بس عشان شكوى واحدة اتغيّرت.
        final updatedComplaints = state.complaints.map((c) {
          if (c.id != event.complaintId) return c;
          return c.copyWith(
            status: ComplaintStatuses.resolved,
            response: event.response,
            updatedAt: DateTime.now(),
          );
        }).toList();

        emit(
          state.copyWith(
            respondComplaintStatus: SubmissionStatus.success,
            complaints: updatedComplaints,
          ),
        );
      },
    );
  }

  void _onResetRespondComplaint(
    ResetRespondComplaintEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        respondComplaintStatus: SubmissionStatus.idle,
        respondComplaintError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // بث إشعار موحّد — admin ops only (H3 / A-H15); not AcademyEventSink
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onSendBroadcast(
    SendBroadcastNotificationEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        broadcastStatus: SubmissionStatus.submitting,
        broadcastError: null,
      ),
    );

    final result = await sendBroadcastNotification(
      BroadcastParams(
        title: event.title,
        body: event.body,
        targetRole: event.targetRole,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          broadcastStatus: SubmissionStatus.error,
          broadcastError: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(broadcastStatus: SubmissionStatus.success)),
    );
  }

  void _onResetBroadcast(ResetBroadcastEvent event, Emitter<AdminState> emit) {
    emit(
      state.copyWith(
        broadcastStatus: SubmissionStatus.idle,
        broadcastError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // إدارة شؤون المعلمين
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadAllTeachers(
    LoadAllTeachersEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        teachersStatus: SectionStatus.loading,
        teachersError: null,
      ),
    );

    final result = await getAllTeachers(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          teachersStatus: SectionStatus.error,
          teachersError: failure.message,
        ),
      ),
      (teachers) => emit(
        state.copyWith(
          teachersStatus: SectionStatus.loaded,
          teachers: teachers,
        ),
      ),
    );
  }

  Future<void> _onUpdateTeacherPerformance(
    UpdateTeacherPerformanceEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        updatePerformanceStatus: SubmissionStatus.submitting,
        updatePerformanceError: null,
      ),
    );

    final result = await updateTeacherPerformance(
      UpdateTeacherPerformanceParams(
        teacherId: event.teacherId,
        rating: event.rating,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          updatePerformanceStatus: SubmissionStatus.error,
          updatePerformanceError: failure.message,
        ),
      ),
      (_) {
        // تحديث القيمة محلياً في القائمة الحالية بدل ما نعمل reload
        // كامل لقائمة المعلمين كلها عشان تقييم معلم واحد اتغيّر.
        final updatedTeachers = state.teachers.map((t) {
          if (t.uid != event.teacherId) return t;
          return TeacherManagementEntity(
            uid: t.uid,
            name: t.name,
            profileImageUrl: t.profileImageUrl,
            halaqatIds: t.halaqatIds,
            performanceRating: event.rating,
            weeklyQuota: t.weeklyQuota,
          );
        }).toList();

        emit(
          state.copyWith(
            updatePerformanceStatus: SubmissionStatus.success,
            teachers: updatedTeachers,
          ),
        );
      },
    );
  }

  void _onResetUpdateTeacherPerformance(
    ResetUpdateTeacherPerformanceEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        updatePerformanceStatus: SubmissionStatus.idle,
        updatePerformanceError: null,
      ),
    );
  }

  Future<void> _onUpdateTeacherQuota(
    UpdateTeacherQuotaEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        updateQuotaStatus: SubmissionStatus.submitting,
        updateQuotaError: null,
      ),
    );

    final result = await updateTeacherQuota(
      UpdateTeacherQuotaParams(
        teacherId: event.teacherId,
        weeklyQuota: event.weeklyQuota,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          updateQuotaStatus: SubmissionStatus.error,
          updateQuotaError: failure.message,
        ),
      ),
      (_) {
        final updatedTeachers = state.teachers.map((t) {
          if (t.uid != event.teacherId) return t;
          return TeacherManagementEntity(
            uid: t.uid,
            name: t.name,
            profileImageUrl: t.profileImageUrl,
            halaqatIds: t.halaqatIds,
            performanceRating: t.performanceRating,
            weeklyQuota: event.weeklyQuota,
          );
        }).toList();

        emit(
          state.copyWith(
            updateQuotaStatus: SubmissionStatus.success,
            teachers: updatedTeachers,
          ),
        );
      },
    );
  }

  void _onResetUpdateTeacherQuota(
    ResetUpdateTeacherQuotaEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        updateQuotaStatus: SubmissionStatus.idle,
        updateQuotaError: null,
      ),
    );
  }

  Future<void> _onLoadTeacherActivityLog(
    LoadTeacherActivityLogEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        teacherActivityStatus: SectionStatus.loading,
        teacherActivityError: null,
      ),
    );

    final result = await getTeacherActivityLog(
      TeacherActivityParams(
        teacherId: event.teacherId,
        from: event.from,
        to: event.to,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          teacherActivityStatus: SectionStatus.error,
          teacherActivityError: failure.message,
        ),
      ),
      (activity) => emit(
        state.copyWith(
          teacherActivityStatus: SectionStatus.loaded,
          teacherActivity: activity,
        ),
      ),
    );
  }

  Future<void> _onLoadStudentRoster(
    LoadStudentRosterEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(rosterStatus: SectionStatus.loading, rosterError: null),
    );
    final result = await getAcademyStudentRoster(const NoParams());
    result.fold(
      (f) => emit(
        state.copyWith(
          rosterStatus: SectionStatus.error,
          rosterError: f.message,
        ),
      ),
      (roster) => emit(
        state.copyWith(
          rosterStatus: SectionStatus.loaded,
          studentRoster: roster,
        ),
      ),
    );
  }

  Future<void> _onLoadRegistrationRequests(
    LoadRegistrationRequestsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        registrationStatus: SectionStatus.loading,
        registrationError: null,
      ),
    );
    final result = await getRegistrationRequests(const NoParams());
    result.fold(
      (f) => emit(
        state.copyWith(
          registrationStatus: SectionStatus.error,
          registrationError: f.message,
        ),
      ),
      (requests) => emit(
        state.copyWith(
          registrationStatus: SectionStatus.loaded,
          registrationRequests: requests,
        ),
      ),
    );
  }

  Future<void> _onLoadAdminDirectory(
    LoadAdminDirectoryEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        directoryStatus: SectionStatus.loading,
        directoryError: null,
      ),
    );
    final halaqatResult = await getAllHalaqat(const NoParams());
    final supervisorsResult = await getAllSupervisors(const NoParams());

    List<AdminHalaqaSummaryEntity>? halaqat;
    List<AdminStaffSummaryEntity>? supervisors;
    String? error;

    halaqatResult.fold((f) => error = f.message, (h) => halaqat = h);
    if (error != null) {
      emit(
        state.copyWith(
          directoryStatus: SectionStatus.error,
          directoryError: error,
        ),
      );
      return;
    }
    supervisorsResult.fold((f) => error = f.message, (s) => supervisors = s);
    if (error != null) {
      emit(
        state.copyWith(
          directoryStatus: SectionStatus.error,
          directoryError: error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        directoryStatus: SectionStatus.loaded,
        halaqatDirectory: halaqat ?? const [],
        supervisorsDirectory: supervisors ?? const [],
      ),
    );
  }

  Future<void> _onRejectRegistration(
    RejectRegistrationRequestEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        registrationActionStatus: SubmissionStatus.submitting,
        registrationActionError: null,
      ),
    );
    final result = await rejectRegistrationRequest(
      RejectRegistrationParams(studentId: event.studentId),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          registrationActionStatus: SubmissionStatus.error,
          registrationActionError: f.message,
        ),
      ),
      (_) {
        final updated = state.registrationRequests
            .where((r) => r.studentId != event.studentId)
            .toList();
        emit(
          state.copyWith(
            registrationActionStatus: SubmissionStatus.success,
            registrationRequests: updated,
          ),
        );
      },
    );
  }

  Future<void> _onApproveRegistration(
    ApproveRegistrationRequestEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        registrationActionStatus: SubmissionStatus.submitting,
        registrationActionError: null,
      ),
    );
    final result = await approveRegistrationRequest(
      ApproveRegistrationParams(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        teacherId: event.teacherId,
        supervisorId: event.supervisorId,
      ),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          registrationActionStatus: SubmissionStatus.error,
          registrationActionError: f.message,
        ),
      ),
      (_) {
        final updated = state.registrationRequests
            .where((r) => r.studentId != event.studentId)
            .toList();
        emit(
          state.copyWith(
            registrationActionStatus: SubmissionStatus.success,
            registrationRequests: updated,
          ),
        );
      },
    );
  }

  void _onResetRegistrationAction(
    ResetRegistrationActionEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        registrationActionStatus: SubmissionStatus.idle,
        registrationActionError: null,
      ),
    );
  }

  Future<void> _onUpdateComplaint(
    UpdateComplaintEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        updateComplaintStatus: SubmissionStatus.submitting,
        updateComplaintError: null,
      ),
    );
    final result = await updateComplaint(
      UpdateComplaintParams(
        complaintId: event.complaintId,
        status: event.status,
        priority: event.priority,
        assigneeId: event.assigneeId,
        assigneeRole: event.assigneeRole,
        response: event.response,
      ),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          updateComplaintStatus: SubmissionStatus.error,
          updateComplaintError: f.message,
        ),
      ),
      (_) {
        final updated = state.complaints.map((c) {
          if (c.id != event.complaintId) return c;
          return c.copyWith(
            status: event.status,
            priority: event.priority,
            assigneeId: event.assigneeId,
            assigneeRole: event.assigneeRole,
            response: event.response,
            updatedAt: DateTime.now(),
          );
        }).toList();
        emit(
          state.copyWith(
            updateComplaintStatus: SubmissionStatus.success,
            complaints: updated,
          ),
        );
      },
    );
  }

  void _onResetUpdateComplaint(
    ResetUpdateComplaintEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        updateComplaintStatus: SubmissionStatus.idle,
        updateComplaintError: null,
      ),
    );
  }

  Future<void> _onLoadCommunicationSettings(
    LoadCommunicationSettingsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        communicationSettingsStatus: SectionStatus.loading,
        communicationSettingsError: null,
      ),
    );
    final result = await getCommunicationSettings(const NoParams());
    result.fold(
      (f) => emit(
        state.copyWith(
          communicationSettingsStatus: SectionStatus.error,
          communicationSettingsError: f.message,
        ),
      ),
      (settings) => emit(
        state.copyWith(
          communicationSettingsStatus: SectionStatus.loaded,
          communicationSettings: settings,
        ),
      ),
    );
  }

  Future<void> _onSaveCommunicationSettings(
    SaveCommunicationSettingsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        saveCommunicationSettingsStatus: SubmissionStatus.submitting,
        saveCommunicationSettingsError: null,
      ),
    );
    final result = await saveCommunicationSettings(event.settings);
    result.fold(
      (f) => emit(
        state.copyWith(
          saveCommunicationSettingsStatus: SubmissionStatus.error,
          saveCommunicationSettingsError: f.message,
        ),
      ),
      (_) => emit(
        state.copyWith(
          saveCommunicationSettingsStatus: SubmissionStatus.success,
          communicationSettings: event.settings,
        ),
      ),
    );
  }

  void _onResetCommunicationSettings(
    ResetCommunicationSettingsEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        saveCommunicationSettingsStatus: SubmissionStatus.idle,
        saveCommunicationSettingsError: null,
      ),
    );
  }

  Future<void> _onGrantReward(
    GrantAdminRewardEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        grantRewardStatus: SubmissionStatus.submitting,
        grantRewardError: null,
      ),
    );
    final result = await grantAdminReward(event.params);
    result.fold(
      (f) => emit(
        state.copyWith(
          grantRewardStatus: SubmissionStatus.error,
          grantRewardError: f.message,
        ),
      ),
      (_) => emit(state.copyWith(grantRewardStatus: SubmissionStatus.success)),
    );
  }

  void _onResetGrantReward(
    ResetGrantRewardEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        grantRewardStatus: SubmissionStatus.idle,
        grantRewardError: null,
      ),
    );
  }

  Future<void> _onCreateHalaqa(
    CreateHalaqaEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        createHalaqaStatus: SubmissionStatus.submitting,
        createHalaqaError: null,
        lastCreatedHalaqaId: null,
      ),
    );
    final result = await createHalaqa(event.params);
    result.fold(
      (f) => emit(
        state.copyWith(
          createHalaqaStatus: SubmissionStatus.error,
          createHalaqaError: f.message,
        ),
      ),
      (id) => emit(
        state.copyWith(
          createHalaqaStatus: SubmissionStatus.success,
          lastCreatedHalaqaId: id,
        ),
      ),
    );
  }

  void _onResetCreateHalaqa(
    ResetCreateHalaqaEvent event,
    Emitter<AdminState> emit,
  ) {
    emit(
      state.copyWith(
        createHalaqaStatus: SubmissionStatus.idle,
        createHalaqaError: null,
      ),
    );
  }

  Future<void> _onEnsureAdminInternalChat(
    EnsureAdminInternalChatEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(
      state.copyWith(
        adminInternalChatStatus: SubmissionStatus.submitting,
        adminInternalChatError: null,
      ),
    );
    final result = await ensureAdminInternalChat(
      EnsureAdminInternalChatParams(adminUid: event.adminUid),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          adminInternalChatStatus: SubmissionStatus.error,
          adminInternalChatError: f.message,
        ),
      ),
      (id) => emit(
        state.copyWith(
          adminInternalChatStatus: SubmissionStatus.success,
          adminInternalChatId: id,
        ),
      ),
    );
  }
}
