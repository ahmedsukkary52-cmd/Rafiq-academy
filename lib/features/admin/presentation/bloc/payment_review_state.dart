part of 'payment_review_bloc.dart';

class PaymentReviewState extends Equatable {
  final SectionStatus status;
  final String? error;
  final List<PaymentReviewItem> items;
  final String reviewerUid;
  final bool isAdmin;
  final SubmissionStatus submissionStatus;
  final String? activePaymentId;
  final String? message;

  /// Decisions whose outcome is still unknown (timeout / network), by
  /// payment: a retry re-sends exactly this command with its `requestId`.
  final Map<String, PaymentReviewCommand> unresolved;

  const PaymentReviewState({
    this.status = SectionStatus.initial,
    this.error,
    this.items = const [],
    this.reviewerUid = '',
    this.isAdmin = false,
    this.submissionStatus = SubmissionStatus.idle,
    this.activePaymentId,
    this.message,
    this.unresolved = const {},
  });

  PaymentReviewState copyWith({
    SectionStatus? status,
    String? error,
    List<PaymentReviewItem>? items,
    String? reviewerUid,
    bool? isAdmin,
    SubmissionStatus? submissionStatus,
    String? activePaymentId,
    String? message,
    bool clearMessage = false,
    Map<String, PaymentReviewCommand>? unresolved,
  }) {
    return PaymentReviewState(
      status: status ?? this.status,
      error: error ?? this.error,
      items: items ?? this.items,
      reviewerUid: reviewerUid ?? this.reviewerUid,
      isAdmin: isAdmin ?? this.isAdmin,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      activePaymentId: activePaymentId ?? this.activePaymentId,
      message: clearMessage ? null : (message ?? this.message),
      unresolved: unresolved ?? this.unresolved,
    );
  }

  /// The unresolved command for [item], only while it is still bound to the
  /// proof the item shows now.
  PaymentReviewCommand? unresolvedFor(PaymentReviewItem item) {
    final command = unresolved[item.paymentId];
    if (command == null) return null;
    return command.targetsProof(
          fileName: item.proofFileName,
          proofCycleId: item.proofCycleId,
        )
        ? command
        : null;
  }

  @override
  List<Object?> get props => [
    status,
    error,
    items,
    reviewerUid,
    isAdmin,
    submissionStatus,
    activePaymentId,
    message,
    unresolved,
  ];
}
