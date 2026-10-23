import 'family_bill_contract.dart';

/// One status per student/family for a billing month, shared by the parent
/// view and the admin report. Derived only from server-written `status` and
/// `reviewStatus`; a submitted or pending proof is never reported as paid.
enum BillingReportStatus {
  paid,
  awaitingProof,
  awaitingVerification,
  overdue,
  rejected,

  /// Legacy single-child invoices with a confirmed partial payment.
  partiallyPaid,

  /// Fee configured but no bill issued for the month yet.
  notYetDue,

  /// No bill and no fee configured: needs admin configuration.
  feeNotConfigured,
  cancelled,

  /// Unrecognised stored values; never treated as paid.
  unknown,
}

extension BillingReportStatusLabel on BillingReportStatus {
  String get arabicLabel => switch (this) {
    BillingReportStatus.paid => 'مدفوع',
    BillingReportStatus.awaitingProof => 'بانتظار إيصال الدفع',
    BillingReportStatus.awaitingVerification => 'إيصال مُرسل — بانتظار التحقق',
    BillingReportStatus.overdue => 'متأخر',
    BillingReportStatus.rejected => 'إيصال مرفوض — بانتظار إعادة الرفع',
    BillingReportStatus.partiallyPaid => 'سداد جزئي',
    BillingReportStatus.notYetDue => 'لم يُستحق بعد',
    BillingReportStatus.feeNotConfigured => 'الرسوم غير مضبوطة',
    BillingReportStatus.cancelled => 'ملغاة',
    BillingReportStatus.unknown => 'حالة غير معروفة',
  };

  bool get isPaid => this == BillingReportStatus.paid;
}

/// Maps a bill/invoice record for one month to its report status.
///
/// [hasRecord] is false when no bill exists for the month; then
/// [feeConfigured] decides between [BillingReportStatus.notYetDue] and
/// [BillingReportStatus.feeNotConfigured]. Overdue comes only from the stored
/// status (D4), never from a client clock.
BillingReportStatus billingReportStatus({
  required bool hasRecord,
  String? status,
  String? reviewStatus,
  bool feeConfigured = true,
}) {
  if (!hasRecord) {
    return feeConfigured
        ? BillingReportStatus.notYetDue
        : BillingReportStatus.feeNotConfigured;
  }
  final s = status?.trim() ?? '';
  final review = reviewStatus?.trim() ?? '';

  if (s == FamilyBillContract.statusCancelled) {
    return BillingReportStatus.cancelled;
  }
  if (s == FamilyBillContract.statusPaid) return BillingReportStatus.paid;
  if (s != FamilyBillContract.statusDue &&
      s != FamilyBillContract.statusOverdue) {
    return BillingReportStatus.unknown;
  }

  switch (review) {
    case FamilyBillContract.reviewPending:
      return BillingReportStatus.awaitingVerification;
    case FamilyBillContract.reviewRejected:
      return BillingReportStatus.rejected;
    case FamilyBillContract.reviewPartial:
      return BillingReportStatus.partiallyPaid;
    case '':
      return s == FamilyBillContract.statusOverdue
          ? BillingReportStatus.overdue
          : BillingReportStatus.awaitingProof;
    default:
      // `approved` without `status == paid`, or an unknown review value, is
      // inconsistent server data — surface it rather than guess.
      return BillingReportStatus.unknown;
  }
}

/// Obligation dimension of a billing month, from the stored `status` only.
enum BillingDueState {
  /// Fee configured but no bill issued for the month yet.
  notYetIssued,

  /// No bill and no fee configured: needs admin configuration.
  feeNotConfigured,

  /// Approved fee exemption: nothing collectible. Distinct from a missing fee.
  exempt,
  due,
  overdue,
  paid,
  cancelled,
  unknown,
}

/// Proof dimension of a billing month, from the stored `reviewStatus` only.
enum BillingProofState {
  none,
  awaitingVerification,
  rejected,
  approved,

  /// Legacy single-child invoices with a confirmed partial payment.
  partial,
  unknown,
}

extension BillingDueStateLabel on BillingDueState {
  String get arabicLabel => switch (this) {
    BillingDueState.notYetIssued => 'لم يُستحق بعد',
    BillingDueState.feeNotConfigured => 'الرسوم غير مضبوطة',
    BillingDueState.exempt => 'معفى من الرسوم',
    BillingDueState.due => 'مستحق',
    BillingDueState.overdue => 'متأخر',
    BillingDueState.paid => 'مدفوع',
    BillingDueState.cancelled => 'ملغاة',
    BillingDueState.unknown => 'حالة غير معروفة',
  };
}

extension BillingProofStateLabel on BillingProofState {
  String get arabicLabel => switch (this) {
    BillingProofState.none => 'لم يُرسل إيصال',
    BillingProofState.awaitingVerification => 'إيصال مُرسل — بانتظار التحقق',
    BillingProofState.rejected => 'إيصال مرفوض',
    BillingProofState.approved => 'إيصال معتمد',
    BillingProofState.partial => 'سداد جزئي',
    BillingProofState.unknown => 'حالة غير معروفة',
  };
}

/// Both report dimensions side by side, so "overdue" and "rejected" are never
/// collapsed into one value.
class BillingReportDimensions {
  const BillingReportDimensions({
    required this.dueState,
    required this.proofState,
    this.latestRejectionReason,
  });

  final BillingDueState dueState;
  final BillingProofState proofState;

  /// Most recent rejection reason; kept after a resubmission.
  final String? latestRejectionReason;

  bool get isPaid => dueState == BillingDueState.paid;

  /// Stored data that does not form a valid combination.
  bool get needsAttention =>
      dueState == BillingDueState.unknown ||
      proofState == BillingProofState.unknown ||
      (proofState == BillingProofState.approved && !isPaid);
}

/// Two-dimension variant of [billingReportStatus].
///
/// [exempt] must come from an explicit approved exemption record; it is only
/// consulted when no bill exists. Paid comes only from `status == paid`.
BillingReportDimensions billingReportDimensions({
  required bool hasRecord,
  String? status,
  String? reviewStatus,
  String? latestRejectionReason,
  bool feeConfigured = true,
  bool exempt = false,
}) {
  final reason = latestRejectionReason?.trim() ?? '';
  final keptReason = reason.isEmpty ? null : reason;

  if (!hasRecord) {
    return BillingReportDimensions(
      dueState: exempt
          ? BillingDueState.exempt
          : feeConfigured
          ? BillingDueState.notYetIssued
          : BillingDueState.feeNotConfigured,
      proofState: BillingProofState.none,
      latestRejectionReason: keptReason,
    );
  }

  final dueState = switch (status?.trim() ?? '') {
    FamilyBillContract.statusDue => BillingDueState.due,
    FamilyBillContract.statusOverdue => BillingDueState.overdue,
    FamilyBillContract.statusPaid => BillingDueState.paid,
    FamilyBillContract.statusCancelled => BillingDueState.cancelled,
    _ => BillingDueState.unknown,
  };
  final proofState = switch (reviewStatus?.trim() ?? '') {
    '' => BillingProofState.none,
    FamilyBillContract.reviewPending => BillingProofState.awaitingVerification,
    FamilyBillContract.reviewRejected => BillingProofState.rejected,
    FamilyBillContract.reviewApproved => BillingProofState.approved,
    FamilyBillContract.reviewPartial => BillingProofState.partial,
    _ => BillingProofState.unknown,
  };

  return BillingReportDimensions(
    dueState: dueState,
    proofState: proofState,
    latestRejectionReason: keptReason,
  );
}
