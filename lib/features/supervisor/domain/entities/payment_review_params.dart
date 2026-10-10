import 'package:equatable/equatable.dart';

/// Supervisor outcome for a payment proof review.
enum PaymentReviewDecision { approved, rejected, partial }

class PaymentReviewParams extends Equatable {
  final String supervisorId;
  final String paymentId;
  final PaymentReviewDecision decision;
  final String? notes;
  final double? amountPaidConfirmed;
  final double? remainingAmount;

  const PaymentReviewParams({
    required this.supervisorId,
    required this.paymentId,
    required this.decision,
    this.notes,
    this.amountPaidConfirmed,
    this.remainingAmount,
  });

  @override
  List<Object?> get props => [
    supervisorId,
    paymentId,
    decision,
    notes,
    amountPaidConfirmed,
    remainingAmount,
  ];
}
