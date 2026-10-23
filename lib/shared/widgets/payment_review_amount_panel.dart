import 'package:flutter/material.dart';

import '../domain/payment_review_amounts.dart';
import '../theme/app_theme.dart';

/// Reviewer's partial-amount input: mode (receipt by default) + typed value.
/// Changing the mode clears the value so a total is never read as a receipt.
class PaymentAmountDraft extends ChangeNotifier {
  final TextEditingController input = TextEditingController();
  PaymentAmountMode _mode = PaymentAmountMode.receipt;

  PaymentAmountDraft() {
    input.addListener(notifyListeners);
  }

  PaymentAmountMode get mode => _mode;

  set mode(PaymentAmountMode value) {
    if (value == _mode) return;
    _mode = value;
    input.clear();
    notifyListeners();
  }

  int? get inputMinorUnits => parseMoneyInput(input.text);

  PaymentReviewCheck check(PaymentAmountSnapshot snapshot) =>
      previewPartialPayment(
        snapshot: snapshot,
        mode: _mode,
        input: inputMinorUnits,
      );

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
}

/// Invoice / previously confirmed / remaining, plus what the selected
/// decision ([PaymentReviewWire]) will record — shown before submitting.
class PaymentReviewAmountPanel extends StatelessWidget {
  final PaymentAmountSnapshot snapshot;
  final String decision;
  final PaymentAmountDraft draft;
  final String currency;
  final bool enabled;

  const PaymentReviewAmountPanel({
    super.key,
    required this.snapshot,
    required this.decision,
    required this.draft,
    this.currency = '',
    this.enabled = true,
  });

  String _money(int units) => currency.isEmpty
      ? formatMinorUnits(units)
      : '${formatMinorUnits(units)} $currency';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final snapshotError = snapshot.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AmountRow(label: 'قيمة الفاتورة', value: _money(snapshot.invoice)),
            if (snapshotError == null) ...[
              _AmountRow(
                label: 'المؤكد سابقاً',
                value: _money(snapshot.previous),
              ),
              _AmountRow(label: 'المتبقي', value: _money(snapshot.remaining)),
            ],
            const SizedBox(height: 8),
            if (snapshotError != null)
              _Message(text: snapshotError, error: true)
            else
              ..._decisionSection(),
          ],
        );
      },
    );
  }

  List<Widget> _decisionSection() {
    switch (decision) {
      case PaymentReviewWire.partial:
        return _partialSection();
      case PaymentReviewWire.approve:
        final preview = previewFullApproval(snapshot).preview!;
        return [
          const _Message(text: 'سيُعتمد كامل الفاتورة'),
          _AmountRow(label: 'يغطي هذا الإيصال', value: _money(preview.receipt)),
          _AmountRow(
            label: 'الإجمالي المؤكد الجديد',
            value: _money(preview.total),
          ),
          _AmountRow(
            label: 'المتبقي المتوقع',
            value: _money(preview.remaining),
          ),
        ];
      default:
        return const [_Message(text: 'الرفض لا يغيّر المبالغ المؤكدة')];
    }
  }

  List<Widget> _partialSection() {
    final mode = draft.mode;
    final hasInput = draft.input.text.trim().isNotEmpty;
    final check = draft.check(snapshot);
    final preview = check.preview;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final m in PaymentAmountMode.values)
            ChoiceChip(
              key: ValueKey('payment-amount-mode-${m.wire}'),
              label: Text(m.label),
              selected: mode == m,
              onSelected: enabled ? (_) => draft.mode = m : null,
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('payment-amount-input'),
        controller: draft.input,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: mode == PaymentAmountMode.receipt
              ? 'قيمة هذا الإيصال'
              : 'الإجمالي المؤكد بعد هذا الإيصال',
          helperText: 'بحد أقصى منزلتين عشريتين',
        ),
      ),
      const SizedBox(height: 8),
      if (!hasInput)
        const _Message(text: 'أدخل المبلغ لعرض الإجمالي الجديد والمتبقي')
      else if (preview == null)
        _Message(text: check.error!, error: true)
      else ...[
        _AmountRow(label: 'قيمة هذا الإيصال', value: _money(preview.receipt)),
        _AmountRow(
          label: 'الإجمالي المؤكد الجديد',
          value: _money(preview.total),
        ),
        _AmountRow(label: 'المتبقي المتوقع', value: _money(preview.remaining)),
      ],
    ];
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;

  const _AmountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;

  const _Message({required this.text, this.error = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: error ? AppColors.error : AppColors.textSecondary,
          fontWeight: error ? FontWeight.w700 : null,
        ),
      ),
    );
  }
}
