import 'package:equatable/equatable.dart';

class FinancialSummaryEntity extends Equatable {
  final double totalRevenue;
  final double totalPending;
  final double totalOverdue;
  final int paidCount;
  final int dueCount;
  final int overdueCount;

  const FinancialSummaryEntity({
    required this.totalRevenue,
    required this.totalPending,
    required this.totalOverdue,
    required this.paidCount,
    required this.dueCount,
    required this.overdueCount,
  });

  @override
  List<Object?> get props => [
    totalRevenue,
    totalPending,
    totalOverdue,
    paidCount,
    dueCount,
    overdueCount,
  ];
}
