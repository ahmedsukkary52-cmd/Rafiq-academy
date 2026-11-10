import 'package:equatable/equatable.dart';

/// Ledger filters over the real lifecycle: `status` (due / overdue / paid)
/// and `reviewStatus == pending_review` for uploaded, unreviewed proofs.
enum PaymentLedgerFilter {
  all('الكل'),
  awaitingReview('بانتظار المراجعة'),
  due('مستحق'),
  overdue('متأخر'),
  paid('مدفوع');

  const PaymentLedgerFilter(this.label);
  final String label;
}

String paymentStatusLabel(String status) => switch (status) {
  'paid' => 'مدفوع',
  'overdue' => 'متأخر',
  _ => 'مستحق',
};

String paymentReviewStatusLabel(String? reviewStatus) => switch (reviewStatus) {
  'pending_review' => 'إيصال بانتظار المراجعة',
  'approved' => 'تم اعتماد الإيصال',
  'partial' => 'اعتماد جزئي',
  'rejected' => 'تم رفض الإيصال',
  _ => 'لم يُرفع إيصال',
};

String paymentMethodLabel(String? method) => switch (method) {
  null || '' => '—',
  'vodafone_cash' => 'فودافون كاش',
  'instapay' => 'إنستاباي',
  _ => method,
};

class PaymentHistoryEntry extends Equatable {
  final DateTime? at;
  final String actorName;
  final String decision;
  final String newStatus;
  final double? receiptAmount;
  final double? remainingAmount;

  const PaymentHistoryEntry({
    this.at,
    required this.actorName,
    required this.decision,
    required this.newStatus,
    this.receiptAmount,
    this.remainingAmount,
  });

  String get decisionLabel => switch (decision) {
    'approve' => 'اعتماد كامل',
    'partial' => 'اعتماد جزئي',
    'reject' => 'رفض الإيصال',
    _ => decision,
  };

  @override
  List<Object?> get props => [
    at,
    actorName,
    decision,
    newStatus,
    receiptAmount,
    remainingAmount,
  ];
}

class AdminPaymentRecord extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String parentId;
  final String parentName;
  final double amount;
  final String status;
  final String? reviewStatus;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? method;
  final String? periodKey;
  final double? amountPaidConfirmed;
  final double? remainingAmount;
  final String? proofStoragePath;
  final DateTime? proofSubmittedAt;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const AdminPaymentRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.parentId,
    required this.parentName,
    required this.amount,
    required this.status,
    this.reviewStatus,
    this.dueDate,
    this.paidAt,
    this.method,
    this.periodKey,
    this.amountPaidConfirmed,
    this.remainingAmount,
    this.proofStoragePath,
    this.proofSubmittedAt,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNotes,
  });

  bool get hasProof => (proofStoragePath ?? '').isNotEmpty;
  bool get awaitingReview => reviewStatus == 'pending_review';

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    parentId,
    parentName,
    amount,
    status,
    reviewStatus,
    dueDate,
    paidAt,
    method,
    periodKey,
    amountPaidConfirmed,
    remainingAmount,
    proofStoragePath,
    proofSubmittedAt,
    reviewedByName,
    reviewedAt,
    reviewNotes,
  ];
}

class AdminPaymentPage {
  final List<AdminPaymentRecord> items;

  /// Opaque cursor for the next page; `null` when there are no more rows.
  final Object? cursor;

  const AdminPaymentPage({required this.items, this.cursor});
}
