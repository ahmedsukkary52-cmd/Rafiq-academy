import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/parent_entities.dart';
import '../../../../shared/domain/parent_payment_proof.dart';
import '../parent_display.dart';

/// Invoice total / confirmed so far / still owed, for an invoice that has
/// partial confirmations. The amount to pay is the remainder, not the total.
class PaymentAmountBreakdown extends StatelessWidget {
  final PaymentEntity payment;

  const PaymentAmountBreakdown({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(label: 'إجمالي الفاتورة', value: parentMoneyLabel(payment.amount)),
        _Row(
          label: 'المؤكد حتى الآن',
          value: parentMoneyLabel(payment.confirmedPartialAmount),
        ),
        _Row(
          label: 'المتبقي للدفع',
          value: parentMoneyLabel(payment.outstandingAmount),
          emphasize: true,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.labelMedium.copyWith(
      color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
