import 'package:equatable/equatable.dart';

import '../../../shared/domain/payment_access_contract.dart';

/// Domain read model for `paymentAccess/{parentId}` (C2).
class PaymentAccessEntity extends Equatable {
  final String parentId;
  final String status;
  final String? reason;
  final String? primaryInvoiceId;
  final List<String> affectedStudentIds;
  final DateTime? graceEndsAt;
  final DateTime? suspendedAt;
  final DateTime? warningIssuedAt;
  final DateTime? lastReminderAt;
  final DateTime? reinstatedAt;
  final String? reinstatedBy;
  final DateTime? updatedAt;

  const PaymentAccessEntity({
    required this.parentId,
    required this.status,
    this.reason,
    this.primaryInvoiceId,
    this.affectedStudentIds = const [],
    this.graceEndsAt,
    this.suspendedAt,
    this.warningIssuedAt,
    this.lastReminderAt,
    this.reinstatedAt,
    this.reinstatedBy,
    this.updatedAt,
  });

  bool get isValidStatus => PaymentAccessContract.isValidStatus(status);

  bool get isSuspended => PaymentAccessContract.isSuspended(status);

  @override
  List<Object?> get props => [
    parentId,
    status,
    reason,
    primaryInvoiceId,
    affectedStudentIds,
    graceEndsAt,
    suspendedAt,
    warningIssuedAt,
    lastReminderAt,
    reinstatedAt,
    reinstatedBy,
    updatedAt,
  ];
}
