import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PaymentEntity - الرسوم والاشتراكات
// ══════════════════════════════════════════════════════════════════════════════

enum PaymentStatus { paid, due, overdue }

class PaymentEntity extends Equatable {
  final String id;
  final String studentId;
  final String parentId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidAt;
  final PaymentStatus status;
  final String? method;

  /// Screenshot proof on Storage (Parent upload). Not confirmation of payment.
  /// Read through Storage Rules; a legacy `proofDownloadUrl` is never used.
  final String? proofStoragePath;
  final DateTime? proofSubmittedAt;
  final String? proofSubmittedBy;
  final String? proofFileName;

  /// Server-issued identity of the current proof submission (null on
  /// payments submitted before proof submission moved server-side).
  final String? proofCycleId;

  /// Supervisor / Admin review fields (see `ParentPaymentProofContract`).
  final String? reviewStatus;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final double? amountPaidConfirmed;
  final double? remainingAmount;

  /// C4 / WA-5 — server invoice snapshot (immutable after create).
  final String? pricingRuleId;
  final int? pricingRuleVersion;
  final DateTime? issuedAt;
  final String? periodKey;
  final String? currency;

  const PaymentEntity({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.amount,
    required this.dueDate,
    this.paidAt,
    required this.status,
    this.method,
    this.proofStoragePath,
    this.proofSubmittedAt,
    this.proofSubmittedBy,
    this.proofFileName,
    this.proofCycleId,
    this.reviewStatus,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.amountPaidConfirmed,
    this.remainingAmount,
    this.pricingRuleId,
    this.pricingRuleVersion,
    this.issuedAt,
    this.periodKey,
    this.currency,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    parentId,
    amount,
    dueDate,
    paidAt,
    status,
    method,
    proofStoragePath,
    proofSubmittedAt,
    proofSubmittedBy,
    proofFileName,
    proofCycleId,
    reviewStatus,
    reviewedBy,
    reviewedAt,
    reviewNotes,
    amountPaidConfirmed,
    remainingAmount,
    pricingRuleId,
    pricingRuleVersion,
    issuedAt,
    periodKey,
    currency,
  ];
}
