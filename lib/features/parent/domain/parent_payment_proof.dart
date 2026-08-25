import 'entities/parent_entities.dart';

/// Parent payment-proof contract (external pay + screenshot).
///
/// Same collection: `payments/{paymentId}` — **no new collection**.
/// Additive optional fields only; [PaymentStatus] stays `due` / `overdue`
/// until Admin confirms (Parent never sets `paid` from a screenshot).
///
/// Fields written by Parent after screenshot upload:
/// - `proofStoragePath` (String)
/// - `proofDownloadUrl` (String)
/// - `proofSubmittedAt` (timestamp)
/// - `proofSubmittedBy` (parent uid)
/// - `proofFileName` (String, optional)
/// - `method` → [externalMethod] (does **not** mean paid)
///
/// Admin approval (sets `status: paid`, `paidAt`) is out of Parent scope.
class ParentPaymentProofContract {
  const ParentPaymentProofContract._();

  static const String proofStoragePathField = 'proofStoragePath';
  static const String proofDownloadUrlField = 'proofDownloadUrl';
  static const String proofSubmittedAtField = 'proofSubmittedAt';
  static const String proofSubmittedByField = 'proofSubmittedBy';
  static const String proofFileNameField = 'proofFileName';

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
  /// Screenshot submitted; still not confirmed until Admin sets `paid`.
  bool get hasProofAwaitingReview {
    if (status == PaymentStatus.paid) return false;
    final path = proofStoragePath?.trim() ?? '';
    return path.isNotEmpty || proofSubmittedAt != null;
  }
}
