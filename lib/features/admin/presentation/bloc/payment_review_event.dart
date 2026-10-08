part of 'payment_review_bloc.dart';

sealed class PaymentReviewEvent extends Equatable {
  const PaymentReviewEvent();

  @override
  List<Object?> get props => [];
}

final class LoadPendingProofsEvent extends PaymentReviewEvent {
  final String reviewerUid;
  final bool isAdmin;

  const LoadPendingProofsEvent({
    required this.reviewerUid,
    required this.isAdmin,
  });

  @override
  List<Object?> get props => [reviewerUid, isAdmin];
}

final class SubmitPaymentReviewEvent extends PaymentReviewEvent {
  final PaymentReviewItem item;
  final PaymentReviewDecision decision;
  final String? notes;
  final double? amountPaidConfirmed;

  const SubmitPaymentReviewEvent({
    required this.item,
    required this.decision,
    this.notes,
    this.amountPaidConfirmed,
  });

  @override
  List<Object?> get props => [item, decision, notes, amountPaidConfirmed];
}

final class ClearPaymentReviewMessageEvent extends PaymentReviewEvent {
  const ClearPaymentReviewMessageEvent();
}
