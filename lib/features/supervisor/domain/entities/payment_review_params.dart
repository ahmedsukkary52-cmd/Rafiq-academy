import 'package:equatable/equatable.dart';

import '../../../../shared/domain/payment_review_amounts.dart';

/// Supervisor outcome for a payment proof review.
enum PaymentReviewDecision { approved, rejected, partial }

extension PaymentReviewDecisionWire on PaymentReviewDecision {
  String get wire => switch (this) {
    PaymentReviewDecision.approved => PaymentReviewWire.approve,
    PaymentReviewDecision.rejected => PaymentReviewWire.reject,
    PaymentReviewDecision.partial => PaymentReviewWire.partial,
  };
}

/// One `reviewPaymentProof` call. [requestId] is stable for a retried
/// identical [command]; [snapshot] is what the reviewer saw.
class PaymentReviewParams extends Equatable {
  final String supervisorId;
  final PaymentReviewCommand command;
  final String requestId;
  final PaymentAmountSnapshot snapshot;

  const PaymentReviewParams({
    required this.supervisorId,
    required this.command,
    required this.requestId,
    required this.snapshot,
  });

  String get paymentId => command.paymentId;

  @override
  List<Object?> get props => [supervisorId, command, requestId, snapshot];
}
