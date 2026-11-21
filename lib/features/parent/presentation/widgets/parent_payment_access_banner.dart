import 'package:flutter/material.dart';

import '../../../../shared/domain/payment_access_contract.dart';
import '../../../../shared/domain/payment_access_entity.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_status_chip.dart';

/// Maps Wave A [PaymentAccessContract] statuses to Parent-facing copy/tone.
/// Presentation only — does not invent statuses or read invoices.
class ParentPaymentAccessLabels {
  const ParentPaymentAccessLabels._();

  static bool shouldSurface(PaymentAccessEntity? access) {
    if (access == null) return false;
    final status = access.status.trim();
    if (status.isEmpty || status == PaymentAccessContract.statusOk) {
      return false;
    }
    return PaymentAccessContract.isValidStatus(status);
  }

  static String title(String status) => switch (status.trim()) {
    PaymentAccessContract.statusReminded => 'تذكير بالسداد',
    PaymentAccessContract.statusDueWarning => 'تنبيه استحقاق',
    PaymentAccessContract.statusInGrace => 'فترة سماح',
    PaymentAccessContract.statusSuspended => 'الوصول معلّق',
    _ => 'حالة السداد',
  };

  static String message(PaymentAccessEntity access) => switch (access.status
      .trim()) {
    PaymentAccessContract.statusReminded =>
      'يوجد مستحقات تحتاج متابعة. يمكنك السداد من تبويب المدفوعات.',
    PaymentAccessContract.statusDueWarning =>
      'اقترب موعد السداد. يُرجى إتمام الدفع عبر الطريقة المتاحة '
          '(فودافون كاش أو إنستاباي) ورفع إثبات الدفع.',
    PaymentAccessContract.statusInGrace =>
      'ما زال الوصول متاحاً خلال فترة السماح، لكن السداد مطلوب قريباً.',
    PaymentAccessContract.statusSuspended =>
      'تم تعليق الوصول بسبب حالة السداد. ادفع الآن أو تواصل مع الإدارة. '
          'لا يُستعاد الوصول تلقائياً قبل إعادة التفعيل من الإدارة.',
    _ =>
      access.reason?.trim().isNotEmpty == true
          ? access.reason!.trim()
          : 'يرجى مراجعة المدفوعات.',
  };

  static AppStatusTone tone(String status) => switch (status.trim()) {
    PaymentAccessContract.statusReminded => AppStatusTone.info,
    PaymentAccessContract.statusDueWarning => AppStatusTone.warning,
    PaymentAccessContract.statusInGrace => AppStatusTone.warning,
    PaymentAccessContract.statusSuspended => AppStatusTone.error,
    _ => AppStatusTone.neutral,
  };

  static String chipLabel(String status) => switch (status.trim()) {
    PaymentAccessContract.statusReminded => 'تذكير',
    PaymentAccessContract.statusDueWarning => 'استحقاق',
    PaymentAccessContract.statusInGrace => 'سماح',
    PaymentAccessContract.statusSuspended => 'معلّق',
    PaymentAccessContract.statusOk => 'منتظم',
    _ => status,
  };
}

/// Surfaces real [PaymentAccessEntity] from ParentBloc — no local inference.
class ParentPaymentAccessBanner extends StatelessWidget {
  final PaymentAccessEntity access;
  final VoidCallback? onPayNow;
  final VoidCallback? onContactAdmin;

  const ParentPaymentAccessBanner({
    super.key,
    required this.access,
    this.onPayNow,
    this.onContactAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final status = access.status.trim();
    final tone = ParentPaymentAccessLabels.tone(status);
    final isSuspended = access.isSuspended;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: _toneColor(tone).withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ParentPaymentAccessLabels.title(status),
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusChip(
                  label: ParentPaymentAccessLabels.chipLabel(status),
                  tone: tone,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ParentPaymentAccessLabels.message(access),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
              textAlign: TextAlign.right,
            ),
            if (onPayNow != null ||
                (isSuspended && onContactAdmin != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onPayNow != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: onPayNow,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                        child: const Text('ادفع الآن'),
                      ),
                    ),
                  if (isSuspended && onContactAdmin != null) ...[
                    if (onPayNow != null) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onContactAdmin,
                        child: const Text('تواصل مع الإدارة'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _toneColor(AppStatusTone tone) => switch (tone) {
    AppStatusTone.success => AppColors.success,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.error => AppColors.error,
    AppStatusTone.info => AppColors.info,
    AppStatusTone.neutral => AppColors.textSecondary,
  };
}
