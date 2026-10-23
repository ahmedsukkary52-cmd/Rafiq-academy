import '../domain/payment_review_amounts.dart';

/// `reviewPaymentProof` request body (current contract). Amounts travel as
/// major units with at most 2 decimals, derived from exact minor units.
Map<String, dynamic> reviewPaymentProofPayload(
  PaymentReviewCommand command, {
  required String requestId,
}) {
  final mode = command.amountMode;
  final amount = command.amountMinorUnits;
  return {
    'paymentId': command.paymentId,
    'decision': command.decision,
    if (command.notes.isNotEmpty) 'notes': command.notes,
    'requestId': requestId,
    'expectedProofFileName': command.expectedProofFileName,
    if (command.expectedProofCycleId.isNotEmpty)
      'expectedProofCycleId': command.expectedProofCycleId,
    if (command.isPartial && mode != null && amount != null) ...{
      'amountMode': mode.wire,
      'amountValue': minorUnitsToMoney(amount),
    },
  };
}

/// `reviewPaymentProof` response. Only `replayed` / `reviewStatus` are read;
/// a missing flag (older server) reads as a fresh review.
PaymentReviewResult reviewPaymentProofResult(
  Object? data,
  PaymentReviewCommand command,
) {
  final map = data is Map ? data : const {};
  final status = map['reviewStatus'];
  return PaymentReviewResult(
    paymentId: command.paymentId,
    reviewStatus: status is String ? status : '',
    replayed: map['replayed'] == true,
  );
}
