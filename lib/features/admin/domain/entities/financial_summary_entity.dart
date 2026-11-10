import 'package:equatable/equatable.dart';

/// Academy-wide payment totals (EGP), computed with server-side aggregates.
///
/// [totalRevenue] is money actually confirmed: fully paid invoices plus
/// supervisor-confirmed partial amounts on unpaid invoices. [totalPending]
/// and [totalOverdue] are what is still outstanding on `due` / `overdue`.
class FinancialSummaryEntity extends Equatable {
  final double totalRevenue;
  final double totalPending;
  final double totalOverdue;
  final int paidCount;
  final int dueCount;
  final int overdueCount;

  /// Proofs uploaded by parents and waiting for a supervisor decision.
  final int awaitingReviewCount;

  const FinancialSummaryEntity({
    required this.totalRevenue,
    required this.totalPending,
    required this.totalOverdue,
    required this.paidCount,
    required this.dueCount,
    required this.overdueCount,
    this.awaitingReviewCount = 0,
  });

  /// Unpaid invoices (the lifecycle's "pending payments").
  int get unpaidCount => dueCount + overdueCount;

  @override
  List<Object?> get props => [
    totalRevenue,
    totalPending,
    totalOverdue,
    paidCount,
    dueCount,
    overdueCount,
    awaitingReviewCount,
  ];
}
