import 'package:equatable/equatable.dart';

import '../../../../shared/utils/attendance_policy.dart';

// AbsenceRequest* types live in shared (H4 / A-H6).
export '../../../../shared/domain/absence_request.dart';

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
  final String? proofStoragePath;
  final String? proofDownloadUrl;
  final DateTime? proofSubmittedAt;
  final String? proofSubmittedBy;
  final String? proofFileName;

  /// Supervisor / Admin review fields (see [ParentPaymentProofContract]).
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
    this.proofDownloadUrl,
    this.proofSubmittedAt,
    this.proofSubmittedBy,
    this.proofFileName,
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
    proofDownloadUrl,
    proofSubmittedAt,
    proofSubmittedBy,
    proofFileName,
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

// ══════════════════════════════════════════════════════════════════════════════
// WeeklyReportEntity - التقرير الأسبوعي لولي الأمر
// ══════════════════════════════════════════════════════════════════════════════

class WeeklyReportEntity extends Equatable {
  final String studentId;
  final String studentName;
  final DateTime weekStart;
  final int totalVersesMemorized;
  final int attendedSessions;
  final int totalSessions;
  final String teacherNotes;

  const WeeklyReportEntity({
    required this.studentId,
    required this.studentName,
    required this.weekStart,
    required this.totalVersesMemorized,
    required this.attendedSessions,
    required this.totalSessions,
    required this.teacherNotes,
  });

  double get attendancePercent => AttendancePolicy.attendancePercent(
    attended: attendedSessions,
    total: totalSessions,
  );

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    weekStart,
    totalVersesMemorized,
    attendedSessions,
    totalSessions,
    teacherNotes,
  ];
}
