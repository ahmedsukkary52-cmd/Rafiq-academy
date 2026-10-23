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

/// [amountMode] / [amountMinorUnits] are read for `partial` only; approval
/// always confirms the full invoice server-side.
final class SubmitPaymentReviewEvent extends PaymentReviewEvent {
  final PaymentReviewItem item;
  final PaymentReviewDecision decision;
  final String? notes;
  final PaymentAmountMode? amountMode;
  final int? amountMinorUnits;

  const SubmitPaymentReviewEvent({
    required this.item,
    required this.decision,
    this.notes,
    this.amountMode,
    this.amountMinorUnits,
  });

  /// Re-sends the item's unresolved command unchanged (same `requestId`).
  factory SubmitPaymentReviewEvent.retry(
    PaymentReviewItem item,
    PaymentReviewCommand command,
  ) => SubmitPaymentReviewEvent(
    item: item,
    decision: PaymentReviewDecision.values.firstWhere(
      (d) => d.wire == command.decision,
    ),
    notes: command.notes,
    amountMode: command.amountMode,
    amountMinorUnits: command.amountMinorUnits,
  );

  @override
  List<Object?> get props => [
    item,
    decision,
    notes,
    amountMode,
    amountMinorUnits,
  ];
}

final class ClearPaymentReviewMessageEvent extends PaymentReviewEvent {
  const ClearPaymentReviewMessageEvent();
}
