import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';

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
  ];
}
