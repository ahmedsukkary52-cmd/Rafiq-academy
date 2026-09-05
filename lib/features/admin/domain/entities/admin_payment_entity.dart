import 'package:equatable/equatable.dart';

/// Payment row from the existing `payments` collection (read-only oversight).
class AdminPaymentEntity extends Equatable {
  final String id;
  final String studentId;
  final String parentId;
  final double amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? method;

  const AdminPaymentEntity({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.method,
  });

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get isDue => status == 'due' || (!isPaid && !isOverdue);

  @override
  List<Object?> get props => [
    id,
    studentId,
    parentId,
    amount,
    status,
    dueDate,
    paidAt,
    method,
  ];
}
