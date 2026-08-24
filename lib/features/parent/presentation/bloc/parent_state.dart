import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_household.dart';
import '../../domain/parent_wallet.dart';
import '../../domain/repositories/parent_repositories.dart';

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
  final List<ParentChildSnapshot> childrenSnapshots;
  final List<ParentStaffContact> staffContacts;
  final ParentFamilySummary familySummary;
  final List<ParentAlert> alerts;

  // ── التقرير الأسبوعي ──────────────────────────────────────────────────
  final SectionStatus reportStatus;
  final WeeklyReportEntity? weeklyReport;
  final String? reportError;

  // ── المدفوعات ──────────────────────────────────────────────────────────
  final SectionStatus paymentsStatus;
  final List<PaymentEntity> payments;
  final String? paymentsError;

  // ── قائمة طلبات الاستئذان (W7 Slice 1) ────────────────────────────────
  final SectionStatus absenceRequestsStatus;
  final List<AbsenceRequestEntity> absenceRequests;
  final String? absenceRequestsError;
  final String? absenceRequestsParentId;

  // ── حلقات الطالب لنموذج الاستئذان ─────────────────────────────────────
  final SectionStatus studentHalaqatStatus;
  final List<ParentHalaqaOption> studentHalaqat;
  final String? studentHalaqatError;
  final String? studentHalaqatStudentId;

  // ── تقديم طلب استئذان ─────────────────────────────────────────────────
  final SubmissionStatus absenceSubmissionStatus;
  final String? absenceSubmissionError;

  // ── بدء عملية دفع ──────────────────────────────────────────────────────
  final SubmissionStatus paymentInitiationStatus;
  final PaymentInitiationEntity? paymentInitiation;
  final String? paymentInitiationError;

  final SectionStatus walletStatus;
  final ParentWalletEntity? wallet;
  final String? walletError;
  final SubmissionStatus walletPayStatus;
  final String? walletPayError;

  final SubmissionStatus paymentProofStatus;
  final String? paymentProofError;
  final String? paymentProofPaymentId;

  const ParentState({
    this.childrenStatus = SectionStatus.initial,
    this.childrenIds = const [],
    this.childrenError,
    this.selectedChildId,
    this.childrenSnapshots = const [],
    this.staffContacts = const [],
    this.familySummary = ParentFamilySummary.empty,
    this.alerts = const [],
    this.reportStatus = SectionStatus.initial,
    this.weeklyReport,
    this.reportError,
    this.paymentsStatus = SectionStatus.initial,
    this.payments = const [],
    this.paymentsError,
    this.absenceRequestsStatus = SectionStatus.initial,
    this.absenceRequests = const [],
    this.absenceRequestsError,
    this.absenceRequestsParentId,
    this.studentHalaqatStatus = SectionStatus.initial,
    this.studentHalaqat = const [],
    this.studentHalaqatError,
    this.studentHalaqatStudentId,
    this.absenceSubmissionStatus = SubmissionStatus.idle,
    this.absenceSubmissionError,
    this.paymentInitiationStatus = SubmissionStatus.idle,
    this.paymentInitiation,
    this.paymentInitiationError,
    this.walletStatus = SectionStatus.initial,
    this.wallet,
    this.walletError,
    this.walletPayStatus = SubmissionStatus.idle,
    this.walletPayError,
    this.paymentProofStatus = SubmissionStatus.idle,
    this.paymentProofError,
    this.paymentProofPaymentId,
  });

  factory ParentState.initial() => const ParentState();

  ParentChildSnapshot? snapshotFor(String studentId) {
    for (final child in childrenSnapshots) {
      if (child.studentId == studentId) return child;
    }
    return null;
  }

  String childDisplayName(String studentId) {
    return snapshotFor(studentId)?.displayName ?? 'طالب';
  }

  ParentState copyWith({
    SectionStatus? childrenStatus,
    List<String>? childrenIds,
    Object? childrenError = _unset,
    Object? selectedChildId = _unset,
    List<ParentChildSnapshot>? childrenSnapshots,
    List<ParentStaffContact>? staffContacts,
    ParentFamilySummary? familySummary,
    List<ParentAlert>? alerts,
    SectionStatus? reportStatus,
    Object? weeklyReport = _unset,
    Object? reportError = _unset,
    SectionStatus? paymentsStatus,
    List<PaymentEntity>? payments,
    Object? paymentsError = _unset,
    SectionStatus? absenceRequestsStatus,
    List<AbsenceRequestEntity>? absenceRequests,
    Object? absenceRequestsError = _unset,
    Object? absenceRequestsParentId = _unset,
    SectionStatus? studentHalaqatStatus,
    List<ParentHalaqaOption>? studentHalaqat,
    Object? studentHalaqatError = _unset,
    Object? studentHalaqatStudentId = _unset,
    SubmissionStatus? absenceSubmissionStatus,
    Object? absenceSubmissionError = _unset,
    SubmissionStatus? paymentInitiationStatus,
    Object? paymentInitiation = _unset,
    Object? paymentInitiationError = _unset,
    SectionStatus? walletStatus,
    Object? wallet = _unset,
    Object? walletError = _unset,
    SubmissionStatus? walletPayStatus,
    Object? walletPayError = _unset,
    SubmissionStatus? paymentProofStatus,
    Object? paymentProofError = _unset,
    Object? paymentProofPaymentId = _unset,
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
      childrenSnapshots: childrenSnapshots ?? this.childrenSnapshots,
      staffContacts: staffContacts ?? this.staffContacts,
      familySummary: familySummary ?? this.familySummary,
      alerts: alerts ?? this.alerts,
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
      absenceRequestsStatus:
          absenceRequestsStatus ?? this.absenceRequestsStatus,
      absenceRequests: absenceRequests ?? this.absenceRequests,
      absenceRequestsError: identical(absenceRequestsError, _unset)
          ? this.absenceRequestsError
          : absenceRequestsError as String?,
      absenceRequestsParentId: identical(absenceRequestsParentId, _unset)
          ? this.absenceRequestsParentId
          : absenceRequestsParentId as String?,
      studentHalaqatStatus: studentHalaqatStatus ?? this.studentHalaqatStatus,
      studentHalaqat: studentHalaqat ?? this.studentHalaqat,
      studentHalaqatError: identical(studentHalaqatError, _unset)
          ? this.studentHalaqatError
          : studentHalaqatError as String?,
      studentHalaqatStudentId: identical(studentHalaqatStudentId, _unset)
          ? this.studentHalaqatStudentId
          : studentHalaqatStudentId as String?,
      absenceSubmissionStatus:
          absenceSubmissionStatus ?? this.absenceSubmissionStatus,
      absenceSubmissionError: identical(absenceSubmissionError, _unset)
          ? this.absenceSubmissionError
          : absenceSubmissionError as String?,
      paymentInitiationStatus:
          paymentInitiationStatus ?? this.paymentInitiationStatus,
      paymentInitiation: identical(paymentInitiation, _unset)
          ? this.paymentInitiation
          : paymentInitiation as PaymentInitiationEntity?,
      paymentInitiationError: identical(paymentInitiationError, _unset)
          ? this.paymentInitiationError
          : paymentInitiationError as String?,
      walletStatus: walletStatus ?? this.walletStatus,
      wallet: identical(wallet, _unset)
          ? this.wallet
          : wallet as ParentWalletEntity?,
      walletError: identical(walletError, _unset)
          ? this.walletError
          : walletError as String?,
      walletPayStatus: walletPayStatus ?? this.walletPayStatus,
      walletPayError: identical(walletPayError, _unset)
          ? this.walletPayError
          : walletPayError as String?,
      paymentProofStatus: paymentProofStatus ?? this.paymentProofStatus,
      paymentProofError: identical(paymentProofError, _unset)
          ? this.paymentProofError
          : paymentProofError as String?,
      paymentProofPaymentId: identical(paymentProofPaymentId, _unset)
          ? this.paymentProofPaymentId
          : paymentProofPaymentId as String?,
    );
  }

  @override
  List<Object?> get props => [
    childrenStatus,
    childrenIds,
    childrenError,
    selectedChildId,
    childrenSnapshots,
    staffContacts,
    familySummary,
    alerts,
    reportStatus,
    weeklyReport,
    reportError,
    paymentsStatus,
    payments,
    paymentsError,
    absenceRequestsStatus,
    absenceRequests,
    absenceRequestsError,
    absenceRequestsParentId,
    studentHalaqatStatus,
    studentHalaqat,
    studentHalaqatError,
    studentHalaqatStudentId,
    absenceSubmissionStatus,
    absenceSubmissionError,
    paymentInitiationStatus,
    paymentInitiation,
    paymentInitiationError,
    walletStatus,
    wallet,
    walletError,
    walletPayStatus,
    walletPayError,
    paymentProofStatus,
    paymentProofError,
    paymentProofPaymentId,
  ];
}
