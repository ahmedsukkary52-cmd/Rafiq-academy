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

  const PaymentReviewState({
    this.status = SectionStatus.initial,
    this.error,
    this.items = const [],
    this.reviewerUid = '',
    this.isAdmin = false,
    this.submissionStatus = SubmissionStatus.idle,
    this.activePaymentId,
    this.message,
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
    );
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
  ];
}
