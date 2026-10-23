import '../../../shared/domain/payment_review_amounts.dart';
import '../../../shared/domain/storage_paths_contract.dart';
import '../../../shared/domain/upload_file_policy.dart';
import 'entities/parent_entities.dart';

/// Parent payment-proof + Supervisor review contract (external pay + screenshot).
///
/// Same collection: `payments/{paymentId}` — **no new collection**.
///
/// Parent uploads the screenshot (Storage, create-only), then calls the
/// [submitCallable]; the server verifies the object and writes:
/// - `proofStoragePath`, `proofSubmittedAt`, `proofSubmittedBy`,
///   `proofFileName`, and a fresh server-issued `proofCycleId`
/// - `proofDownloadUrl` is legacy: cleared on resubmit, never read
/// - `method` → [externalMethod]
/// - `reviewStatus` → [pendingReview] (does **not** mean paid)
///
/// Clients never write `payments/{id}` (firestore.rules). A review is bound
/// to the `proofCycleId` the reviewer saw.
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
  static const String proofCycleIdField = 'proofCycleId';

  /// Server-authoritative submission callable (europe-west1).
  static const String submitCallable = 'submitPaymentProof';

  static final RegExp _cycleId = RegExp(r'^pc_[A-Za-z0-9_-]{16,64}$');

  /// Shape of a server-issued proof cycle; anything else is treated as none.
  static bool isProofCycleId(String? raw) => _cycleId.hasMatch(raw ?? '');

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
    return StoragePathsContract.paymentProof(
      parentId: parentId,
      paymentId: paymentId,
      fileName: fileName,
    );
  }

  /// Max proof size (matches Parent UI copy: ١٠ ميجا).
  static const int maxBytes = UploadFilePolicy.imageMaxBytes;

  /// JPEG / PNG / WebP screenshots (the Parent picker's formats).
  static const List<UploadFormat> formats = UploadFilePolicy.imageFormats;

  static final RegExp _fileName = RegExp(
    r'^[A-Za-z0-9_-]{1,64}\.(jpg|jpeg|png|webp)$',
  );

  /// `{timestamp}.{ext}` — same shape firestore.rules and storage.rules accept.
  static String proofFileName(UploadFormat format, {DateTime? now}) =>
      '${(now ?? DateTime.now()).millisecondsSinceEpoch}.${format.extension}';

  /// True only for `payment_proofs/{parentId}/{paymentId}/{name}.{img}` of
  /// this exact parent and payment. Anything else is never loaded.
  static bool isTrustedStoragePath(
    String? path, {
    required String parentId,
    required String paymentId,
  }) {
    final p = path?.trim() ?? '';
    final parent = parentId.trim();
    final payment = paymentId.trim();
    if (p.isEmpty || parent.isEmpty || payment.isEmpty) return false;
    final parts = p.split('/');
    return parts.length == 4 &&
        parts[0] == StoragePathsContract.paymentProofsPrefix &&
        parts[1] == parent &&
        parts[2] == payment &&
        _fileName.hasMatch(parts[3]);
  }

  /// Legacy empty constant — Vodafone destination is loaded from
  /// `academySettings/paymentPublic` (C3). Do not hard-code a number here.
  @Deprecated('Use academySettings/paymentPublic via Parent datasource')
  static const String transferDestination = '';
}

/// Uploaded proofs whose [ParentPaymentProofContract.submitCallable] outcome
/// is unknown (lost response / network). Retrying the same local file reuses
/// the uploaded name, so the server replays the cycle it already opened
/// instead of a second upload opening another one. Stored objects cannot be
/// overwritten, so the name is never re-uploaded.
class UnconfirmedProofUploads {
  final Map<String, ({String localFilePath, String fileName})> _byPayment = {};

  /// Callable errors that settle the attempt: the server answered, so the
  /// same upload is never retried.
  static const Set<String> definitiveCodes = {
    'invalid-argument',
    'failed-precondition',
    'permission-denied',
    'not-found',
    'unauthenticated',
    'already-exists',
    'out-of-range',
  };

  String? reusableFileName(String paymentId, String localFilePath) {
    final entry = _byPayment[paymentId];
    return entry != null && entry.localFilePath == localFilePath
        ? entry.fileName
        : null;
  }

  void remember(String paymentId, String localFilePath, String fileName) {
    _byPayment[paymentId] = (localFilePath: localFilePath, fileName: fileName);
  }

  void settle(String paymentId) => _byPayment.remove(paymentId);
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

  PaymentAmountSnapshot get _amountSnapshot =>
      PaymentAmountSnapshot.fromAmounts(
        invoiceAmount: amount,
        amountPaidConfirmed: amountPaidConfirmed,
      );

  /// Cumulative total confirmed by partial reviews on an unpaid invoice. It
  /// survives a later proof upload or rejection (the server never resets it).
  bool get hasPartialConfirmation {
    if (status == PaymentStatus.paid) return false;
    final snapshot = _amountSnapshot;
    return snapshot.isValid && snapshot.previous > 0;
  }

  double get confirmedPartialAmount =>
      hasPartialConfirmation ? minorUnitsToMoney(_amountSnapshot.previous) : 0;

  /// What the Parent still owes: invoice − confirmed total (0 once paid).
  double get outstandingAmount {
    if (status == PaymentStatus.paid) return 0;
    final snapshot = _amountSnapshot;
    return snapshot.isValid ? minorUnitsToMoney(snapshot.remaining) : amount;
  }
}
