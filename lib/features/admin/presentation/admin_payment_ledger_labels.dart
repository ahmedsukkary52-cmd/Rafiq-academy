import '../../../shared/domain/payment_status_label.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../domain/entities/admin_payment_record.dart';

/// Presentation-only labels for admin payment ledger rows (no I/O).

String adminPaymentLedgerDate(DateTime? date) =>
    date == null ? '—' : '${date.day}/${date.month}/${date.year}';

AppStatusTone adminPaymentLedgerTone(AdminPaymentRecord payment) {
  if (payment.awaitingReview) return AppStatusTone.info;
  return switch (payment.status) {
    'paid' => AppStatusTone.success,
    'overdue' => AppStatusTone.error,
    _ => AppStatusTone.warning,
  };
}

String adminPaymentLedgerChipLabel(AdminPaymentRecord payment) =>
    payment.awaitingReview
    ? 'بانتظار المراجعة'
    : paymentStatusLabel(payment.status);
