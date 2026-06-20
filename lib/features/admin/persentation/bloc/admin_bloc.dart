import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/approve_new_student_usecase.dart';
import '../../domain/usecases/get_academy_stats_usecase.dart';
import '../../domain/usecases/get_complaints_usecase.dart';
import '../../domain/usecases/get_financial_summary_usecase.dart';
import '../../domain/usecases/respond_to_complaint_usecase.dart';
import '../../domain/usecases/send_broadcast_notification_usecase.dart';
import '../../domain/usecases/toggle_account_status_usecase.dart';
import 'admin_event.dart';
import 'admin_state.dart';

@singleton
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final GetAcademyStatsUseCase getAcademyStats;
  final GetFinancialSummaryUseCase getFinancialSummary;
  final GetComplaintsUseCase getComplaints;
  final ApproveNewStudentUseCase approveNewStudent;
  final ToggleAccountStatusUseCase toggleAccountStatus;
  final RespondToComplaintUseCase respondToComplaint;
  final SendBroadcastNotificationUseCase sendBroadcastNotification;

  AdminBloc({
    required this.getAcademyStats,
    required this.getFinancialSummary,
    required this.getComplaints,
    required this.approveNewStudent,
    required this.toggleAccountStatus,
    required this.respondToComplaint,
    required this.sendBroadcastNotification,
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
          return ComplaintEntity(
            id: c.id,
            senderId: c.senderId,
            senderRole: c.senderRole,
            subject: c.subject,
            message: c.message,
            status: 'resolved',
            response: event.response,
            createdAt: c.createdAt,
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
  // بث إشعار موحّد
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
}
