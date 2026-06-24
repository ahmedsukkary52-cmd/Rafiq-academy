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

  // ── بدء عملية دفع ──────────────────────────────────────────────────────
  final SubmissionStatus paymentInitiationStatus;
  final PaymentInitiationEntity? paymentInitiation;
  final String? paymentInitiationError;

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
    this.paymentInitiationStatus = SubmissionStatus.idle,
    this.paymentInitiation,
    this.paymentInitiationError,
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
    SubmissionStatus? paymentInitiationStatus,
    Object? paymentInitiation = _unset,
    Object? paymentInitiationError = _unset,
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
      paymentInitiationStatus:
          paymentInitiationStatus ?? this.paymentInitiationStatus,
      paymentInitiation: identical(paymentInitiation, _unset)
          ? this.paymentInitiation
          : paymentInitiation as PaymentInitiationEntity?,
      paymentInitiationError: identical(paymentInitiationError, _unset)
          ? this.paymentInitiationError
          : paymentInitiationError as String?,
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
    paymentInitiationStatus,
    paymentInitiation,
    paymentInitiationError,
  ];
}
// todo: (Secret Key)  egy_sk_test_1ebfeaee176d7c453d02f5391204acb70d9795e8cc05e8d58852ce16c519362e
// todo: (HMAC) 70AFB4C3E0AEED71FBDFB68AAFB3AB9B
// todo: (Integration ID) 5488530
// todo: (public Key) egy_pk_test_u5n0kjxAZZaFNb9W4mmJp7j034K8G5D9
// todo: (APO Key) ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFeU5qZ3lOU3dpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5JSVlYTFB0R2VPanZWa2RkdUJkakFiMEhFR3YtT1RhdWpqakFIbk0zbzh3NmNhX2lITjM0VGhwZFNxLUR2ZHhLR3ZVOW5hQjNrYmlEZlgxTmt1TkxuUQ==

// cd functions
// npm install
//
// # سجّل الأسرار (هتاخدهم من Paymob Dashboard)
// firebase functions:secrets:set egy_sk_test_1ebfeaee176d7c453d02f5391204acb70d9795e8cc05e8d58852ce16c519362e
// firebase functions:secrets:set 70AFB4C3E0AEED71FBDFB68AAFB3AB9B
// firebase functions:secrets:set egy_pk_test_u5n0kjxAZZaFNb9W4mmJp7j034K8G5D9
// firebase functions:secrets:set 5488530
//
// # انشر
// firebase deploy --only functions