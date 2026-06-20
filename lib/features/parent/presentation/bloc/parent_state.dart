import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/parent_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class ParentState extends Equatable {
  // ── الأبناء ────────────────────────────────────────────────────────────
  final SectionStatus childrenStatus;
  final List<String> childrenIds;
  final String? childrenError;
  final String? selectedChildId;

  // ── التقرير الأسبوعي ──────────────────────────────────────────────────
  final SectionStatus reportStatus;
  final WeeklyReportEntity? weeklyReport;
  final String? reportError;

  // ── المدفوعات ──────────────────────────────────────────────────────────
  final SectionStatus paymentsStatus;
  final List<PaymentEntity> payments;
  final String? paymentsError;

  // ── تقديم طلب استئذان ─────────────────────────────────────────────────
  final SubmissionStatus absenceSubmissionStatus;
  final String? absenceSubmissionError;

  const ParentState({
    this.childrenStatus = SectionStatus.initial,
    this.childrenIds = const [],
    this.childrenError,
    this.selectedChildId,
    this.reportStatus = SectionStatus.initial,
    this.weeklyReport,
    this.reportError,
    this.paymentsStatus = SectionStatus.initial,
    this.payments = const [],
    this.paymentsError,
    this.absenceSubmissionStatus = SubmissionStatus.idle,
    this.absenceSubmissionError,
  });

  factory ParentState.initial() => const ParentState();

  ParentState copyWith({
    SectionStatus? childrenStatus,
    List<String>? childrenIds,
    Object? childrenError = _unset,
    Object? selectedChildId = _unset,
    SectionStatus? reportStatus,
    Object? weeklyReport = _unset,
    Object? reportError = _unset,
    SectionStatus? paymentsStatus,
    List<PaymentEntity>? payments,
    Object? paymentsError = _unset,
    SubmissionStatus? absenceSubmissionStatus,
    Object? absenceSubmissionError = _unset,
  }) {
    return ParentState(
      childrenStatus: childrenStatus ?? this.childrenStatus,
      childrenIds: childrenIds ?? this.childrenIds,
      childrenError: identical(childrenError, _unset)
          ? this.childrenError
          : childrenError as String?,
      selectedChildId: identical(selectedChildId, _unset)
          ? this.selectedChildId
          : selectedChildId as String?,
      reportStatus: reportStatus ?? this.reportStatus,
      weeklyReport: identical(weeklyReport, _unset)
          ? this.weeklyReport
          : weeklyReport as WeeklyReportEntity?,
      reportError: identical(reportError, _unset)
          ? this.reportError
          : reportError as String?,
      paymentsStatus: paymentsStatus ?? this.paymentsStatus,
      payments: payments ?? this.payments,
      paymentsError: identical(paymentsError, _unset)
          ? this.paymentsError
          : paymentsError as String?,
      absenceSubmissionStatus:
          absenceSubmissionStatus ?? this.absenceSubmissionStatus,
      absenceSubmissionError: identical(absenceSubmissionError, _unset)
          ? this.absenceSubmissionError
          : absenceSubmissionError as String?,
    );
  }

  @override
  List<Object?> get props => [
    childrenStatus,
    childrenIds,
    childrenError,
    selectedChildId,
    reportStatus,
    weeklyReport,
    reportError,
    paymentsStatus,
    payments,
    paymentsError,
    absenceSubmissionStatus,
    absenceSubmissionError,
  ];
}
