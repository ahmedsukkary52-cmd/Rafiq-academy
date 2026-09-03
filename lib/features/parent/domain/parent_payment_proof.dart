import 'entities/parent_entities.dart';

/// Parent payment-proof + Supervisor review contract (external pay + screenshot).
///
/// Same collection: `payments/{paymentId}` — **no new collection**.
///
/// Parent after screenshot upload:
/// - `proofStoragePath`, `proofDownloadUrl`, `proofSubmittedAt`,
///   `proofSubmittedBy`, `proofFileName`
/// - `method` → [externalMethod]
/// - `reviewStatus` → [pendingReview] (does **not** mean paid)
///
/// Supervisor review (scoped to assigned-halaqa students):
/// - `reviewStatus` → approved | rejected | partial
/// - `reviewedBy`, `reviewedAt`, `reviewNotes`
/// - `amountPaidConfirmed`, `remainingAmount`
/// - On **approved**: also sets `status: paid` + `paidAt` (operational confirm)
///
/// Parent must never write review / status-paid fields.
class ParentPaymentProofContract {
  const ParentPaymentProofContract._();

  static const String proofStoragePathField = 'proofStoragePath';
  static const String proofDownloadUrlField = 'proofDownloadUrl';
  static const String proofSubmittedAtField = 'proofSubmittedAt';
  static const String proofSubmittedByField = 'proofSubmittedBy';
  static const String proofFileNameField = 'proofFileName';

  static const String reviewStatusField = 'reviewStatus';
  static const String reviewedByField = 'reviewedBy';
  static const String reviewedAtField = 'reviewedAt';
  static const String reviewNotesField = 'reviewNotes';
  static const String amountPaidConfirmedField = 'amountPaidConfirmed';
  static const String remainingAmountField = 'remainingAmount';

  static const String pendingReview = 'pending_review';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String partial = 'partial';

  /// External channel agreed for this product (not Paymob / not wallet).
  static const String externalMethod = 'vodafone_cash';

  /// Storage root: `payment_proofs/{parentId}/{paymentId}/{fileName}`
  static String storagePath({
    required String parentId,
    required String paymentId,
    required String fileName,
  }) {
    return 'payment_proofs/$parentId/$paymentId/$fileName';
  }

  /// Max proof size (matches Parent UI copy: ١٠ ميجا).
  static const int maxBytes = 10 * 1024 * 1024;

  /// Product-configured Vodafone Cash destination (phone / deep link).
  /// Empty ⇒ instructions-only UI (no invented academy number).
  static const String transferDestination = '';
}

extension PaymentProofStatusX on PaymentEntity {
  /// Screenshot submitted; still awaiting Supervisor review / not confirmed.
  bool get hasProofAwaitingReview {
    if (status == PaymentStatus.paid) return false;
    final review = reviewStatus?.trim() ?? '';
    if (review == ParentPaymentProofContract.approved) return false;
    if (review == ParentPaymentProofContract.pendingReview) return true;
    if (review == ParentPaymentProofContract.rejected ||
        review == ParentPaymentProofContract.partial) {
      return false;
    }
    final path = proofStoragePath?.trim() ?? '';
    return path.isNotEmpty || proofSubmittedAt != null;
  }

  bool get hasSupervisorReview {
    final review = reviewStatus?.trim() ?? '';
    return review == ParentPaymentProofContract.approved ||
        review == ParentPaymentProofContract.rejected ||
        review == ParentPaymentProofContract.partial;
  }
}
