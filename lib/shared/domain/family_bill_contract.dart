/// Family bill contract (docs/production/BILLING_PAYMENT_CONTRACT.md).
///
/// `familyBills/{parentId}_{periodKey}` is written only by the backend; no
/// writer, rules or callable exist yet (planned for later batches). Amounts
/// are integer minor units (piasters) computed server-side
/// (`functions/src/billing/familyBillCalculation.ts`); clients display them
/// and never recompute authoritative totals.
class FamilyBillContract {
  const FamilyBillContract._();

  static const String collection = 'familyBills';

  static String docId({required String parentId, required String periodKey}) =>
      '${parentId.trim()}_${periodKey.trim()}';

  // Identity + period
  static const String parentIdField = 'parentId';
  static const String periodKeyField = 'periodKey';
  static const String currencyField = 'currency';
  static const String dueDateField = 'dueDate';
  static const String issuedAtField = 'issuedAt';

  // Snapshot amounts (minor units)
  static const String linesField = 'lines';
  static const String subtotalMinorField = 'subtotalMinor';
  static const String discountMinorField = 'discountMinor';
  static const String totalMinorField = 'totalMinor';
  static const String discountRuleField = 'discountRule';

  // Line fields
  static const String lineStudentIdField = 'studentId';
  static const String lineStudentNameField = 'studentName';
  static const String lineHalaqaIdField = 'halaqaId';
  static const String linePaymentIdField = 'paymentId';
  static const String lineFeeMinorField = 'feeMinor';
  static const String lineDiscountMinorField = 'discountMinor';
  static const String lineAmountMinorField = 'amountMinor';

  // Discount rule fields
  static const String discountTypeField = 'type';
  static const String discountValueMinorField = 'valueMinor';
  static const String discountBasisPointsField = 'basisPoints';
  static const String discountTypeFixed = 'fixed';
  static const String discountTypePercentage = 'percentage';

  // Lifecycle (same values as `payments`)
  static const String statusField = 'status';
  static const String statusDue = 'due';
  static const String statusOverdue = 'overdue';
  static const String statusPaid = 'paid';
  static const String statusCancelled = 'cancelled';

  static const String reviewStatusField = 'reviewStatus';
  static const String reviewPending = 'pending_review';
  static const String reviewApproved = 'approved';
  static const String reviewRejected = 'rejected';

  /// Legacy single-child invoices only; never set on a family bill.
  static const String reviewPartial = 'partial';

  // Payment method chosen by the parent at proof submission
  static const String methodField = 'method';
  static const String methodVodafoneCash = 'vodafone_cash';
  static const String methodInstapay = 'instapay';

  // Review (server-written)
  static const String reviewedByField = 'reviewedBy';
  static const String reviewedAtField = 'reviewedAt';
  static const String proofSubmittedAtField = 'proofSubmittedAt';
  static const String proofCycleIdField = 'proofCycleId';

  // Policy (contract §3)
  static const int gracePeriodDays = 7;
  static const int familyDiscountMinDueChildren = 2;
  static const int basisPointsPerWhole = 10000;
}
