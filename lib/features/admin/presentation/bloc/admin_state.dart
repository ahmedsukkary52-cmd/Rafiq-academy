import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AdminState extends Equatable {
  // ── إحصائيات الأكاديمية ───────────────────────────────────────────────
  final SectionStatus statsStatus;
  final AcademyStatsEntity? stats;
  final String? statsError;

  // ── الملخص المالي ─────────────────────────────────────────────────────
  final SectionStatus financialStatus;
  final FinancialSummaryEntity? financialSummary;
  final String? financialError;

  // ── الشكاوى ───────────────────────────────────────────────────────────
  final SectionStatus complaintsStatus;
  final List<ComplaintEntity> complaints;
  final String? complaintsError;

  // ── عمليات الإدارة (قبول طالب، تفعيل حساب، رد على شكوى، بث إشعار) ──────
  final SubmissionStatus approveStudentStatus;
  final String? approveStudentError;

  final SubmissionStatus toggleAccountStatus;
  final String? toggleAccountError;

  final SubmissionStatus respondComplaintStatus;
  final String? respondComplaintError;

  final SubmissionStatus broadcastStatus;
  final String? broadcastError;

  // ── إدارة شؤون المعلمين ───────────────────────────────────────────────
  final SectionStatus teachersStatus;
  final List<TeacherManagementEntity> teachers;
  final String? teachersError;

  final SubmissionStatus updatePerformanceStatus;
  final String? updatePerformanceError;

  final SubmissionStatus updateQuotaStatus;
  final String? updateQuotaError;

  final SectionStatus teacherActivityStatus;
  final TeacherActivityEntity? teacherActivity;
  final String? teacherActivityError;

  const AdminState({
    this.statsStatus = SectionStatus.initial,
    this.stats,
    this.statsError,
    this.financialStatus = SectionStatus.initial,
    this.financialSummary,
    this.financialError,
    this.complaintsStatus = SectionStatus.initial,
    this.complaints = const [],
    this.complaintsError,
    this.approveStudentStatus = SubmissionStatus.idle,
    this.approveStudentError,
    this.toggleAccountStatus = SubmissionStatus.idle,
    this.toggleAccountError,
    this.respondComplaintStatus = SubmissionStatus.idle,
    this.respondComplaintError,
    this.broadcastStatus = SubmissionStatus.idle,
    this.broadcastError,
    this.teachersStatus = SectionStatus.initial,
    this.teachers = const [],
    this.teachersError,
    this.updatePerformanceStatus = SubmissionStatus.idle,
    this.updatePerformanceError,
    this.updateQuotaStatus = SubmissionStatus.idle,
    this.updateQuotaError,
    this.teacherActivityStatus = SectionStatus.initial,
    this.teacherActivity,
    this.teacherActivityError,
  });

  factory AdminState.initial() => const AdminState();

  AdminState copyWith({
    SectionStatus? statsStatus,
    Object? stats = _unset,
    Object? statsError = _unset,
    SectionStatus? financialStatus,
    Object? financialSummary = _unset,
    Object? financialError = _unset,
    SectionStatus? complaintsStatus,
    List<ComplaintEntity>? complaints,
    Object? complaintsError = _unset,
    SubmissionStatus? approveStudentStatus,
    Object? approveStudentError = _unset,
    SubmissionStatus? toggleAccountStatus,
    Object? toggleAccountError = _unset,
    SubmissionStatus? respondComplaintStatus,
    Object? respondComplaintError = _unset,
    SubmissionStatus? broadcastStatus,
    Object? broadcastError = _unset,
    SectionStatus? teachersStatus,
    List<TeacherManagementEntity>? teachers,
    Object? teachersError = _unset,
    SubmissionStatus? updatePerformanceStatus,
    Object? updatePerformanceError = _unset,
    SubmissionStatus? updateQuotaStatus,
    Object? updateQuotaError = _unset,
    SectionStatus? teacherActivityStatus,
    Object? teacherActivity = _unset,
    Object? teacherActivityError = _unset,
  }) {
    return AdminState(
      statsStatus: statsStatus ?? this.statsStatus,
      stats: identical(stats, _unset)
          ? this.stats
          : stats as AcademyStatsEntity?,
      statsError: identical(statsError, _unset)
          ? this.statsError
          : statsError as String?,
      financialStatus: financialStatus ?? this.financialStatus,
      financialSummary: identical(financialSummary, _unset)
          ? this.financialSummary
          : financialSummary as FinancialSummaryEntity?,
      financialError: identical(financialError, _unset)
          ? this.financialError
          : financialError as String?,
      complaintsStatus: complaintsStatus ?? this.complaintsStatus,
      complaints: complaints ?? this.complaints,
      complaintsError: identical(complaintsError, _unset)
          ? this.complaintsError
          : complaintsError as String?,
      approveStudentStatus: approveStudentStatus ?? this.approveStudentStatus,
      approveStudentError: identical(approveStudentError, _unset)
          ? this.approveStudentError
          : approveStudentError as String?,
      toggleAccountStatus: toggleAccountStatus ?? this.toggleAccountStatus,
      toggleAccountError: identical(toggleAccountError, _unset)
          ? this.toggleAccountError
          : toggleAccountError as String?,
      respondComplaintStatus:
          respondComplaintStatus ?? this.respondComplaintStatus,
      respondComplaintError: identical(respondComplaintError, _unset)
          ? this.respondComplaintError
          : respondComplaintError as String?,
      broadcastStatus: broadcastStatus ?? this.broadcastStatus,
      broadcastError: identical(broadcastError, _unset)
          ? this.broadcastError
          : broadcastError as String?,
      teachersStatus: teachersStatus ?? this.teachersStatus,
      teachers: teachers ?? this.teachers,
      teachersError: identical(teachersError, _unset)
          ? this.teachersError
          : teachersError as String?,
      updatePerformanceStatus:
          updatePerformanceStatus ?? this.updatePerformanceStatus,
      updatePerformanceError: identical(updatePerformanceError, _unset)
          ? this.updatePerformanceError
          : updatePerformanceError as String?,
      updateQuotaStatus: updateQuotaStatus ?? this.updateQuotaStatus,
      updateQuotaError: identical(updateQuotaError, _unset)
          ? this.updateQuotaError
          : updateQuotaError as String?,
      teacherActivityStatus:
          teacherActivityStatus ?? this.teacherActivityStatus,
      teacherActivity: identical(teacherActivity, _unset)
          ? this.teacherActivity
          : teacherActivity as TeacherActivityEntity?,
      teacherActivityError: identical(teacherActivityError, _unset)
          ? this.teacherActivityError
          : teacherActivityError as String?,
    );
  }

  @override
  List<Object?> get props => [
    statsStatus,
    stats,
    statsError,
    financialStatus,
    financialSummary,
    financialError,
    complaintsStatus,
    complaints,
    complaintsError,
    approveStudentStatus,
    approveStudentError,
    toggleAccountStatus,
    toggleAccountError,
    respondComplaintStatus,
    respondComplaintError,
    broadcastStatus,
    broadcastError,
    teachersStatus,
    teachers,
    teachersError,
    updatePerformanceStatus,
    updatePerformanceError,
    updateQuotaStatus,
    updateQuotaError,
    teacherActivityStatus,
    teacherActivity,
    teacherActivityError,
  ];
}