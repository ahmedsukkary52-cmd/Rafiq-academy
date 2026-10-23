import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/academy_payment_destinations.dart';
import '../../../../shared/theme/app_theme.dart';

typedef PaymentLinkOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

abstract final class ParentPaymentMethodsText {
  static const String loading = 'جارٍ تحميل وسائل الدفع المعتمدة…';
  static const String loadFailed =
      'تعذر تحميل وسائل الدفع المعتمدة. تحقق من اتصالك ثم أعد المحاولة.';
  static const String retry = 'إعادة المحاولة';
  static const String vodafoneCashTitle = 'فودافون كاش';
  static const String instapayTitle = 'إنستاباي';
  static const String vodafoneCashUnset =
      'لم تُحدِّد الأكاديمية رقم محفظة فودافون كاش بعد.';
  static const String instapayUnset =
      'لم تُحدِّد الأكاديمية وجهة التحويل عبر إنستاباي بعد.';
  static const String vodafoneCashInvalid =
      'رقم محفظة فودافون كاش المسجَّل غير صالح حالياً. يُرجى إبلاغ إدارة الأكاديمية.';
  static const String instapayInvalid =
      'وجهة إنستاباي المسجَّلة غير صالحة حالياً. يُرجى إبلاغ إدارة الأكاديمية.';
  static const String walletLabel = 'رقم المحفظة';
  static const String instapayAddressLabel = 'عنوان إنستاباي';
  static const String instapayLinkLabel = 'رابط الدفع';
  static const String openInstapayLink = 'فتح رابط إنستاباي';
  static const String linkOpenFailed =
      'تعذر فتح رابط إنستاباي. انسخ الرابط وافتحه من المتصفح.';
  static const String copied = 'تم النسخ';
}

/// Shows each academy payment method with its own configured destination.
class ParentPaymentMethodsPanel extends StatelessWidget {
  final SectionStatus status;
  final String vodafoneCashDestination;
  final String instapayDestination;
  final VoidCallback onRetry;
  final PaymentLinkOpener openLink;

  const ParentPaymentMethodsPanel({
    super.key,
    required this.status,
    required this.vodafoneCashDestination,
    required this.instapayDestination,
    required this.onRetry,
    this.openLink = _openExternally,
  });

  @override
  Widget build(BuildContext context) {
    if (status == SectionStatus.initial || status == SectionStatus.loading) {
      return const Padding(
        key: Key('payment-methods-loading'),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text(ParentPaymentMethodsText.loading)),
          ],
        ),
      );
    }
    if (status == SectionStatus.error) {
      return _Notice(
        key: const Key('payment-methods-load-error'),
        text: ParentPaymentMethodsText.loadFailed,
        color: AppColors.error,
        action: TextButton(
          onPressed: onRetry,
          child: const Text(ParentPaymentMethodsText.retry),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VodafoneCashCard(destination: vodafoneCashDestination),
        const SizedBox(height: 10),
        _InstapayCard(destination: instapayDestination, openLink: openLink),
      ],
    );
  }
}

class _VodafoneCashCard extends StatelessWidget {
  final String destination;

  const _VodafoneCashCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    final raw = destination.trim();
    final Widget body;
    if (raw.isEmpty) {
      body = const _Notice(
        key: Key('vodafone-cash-unset'),
        text: ParentPaymentMethodsText.vodafoneCashUnset,
        color: AppColors.textSecondary,
      );
    } else if (!AcademyPaymentDestinations.isValidVodafoneCash(raw)) {
      body = const _Notice(
        key: Key('vodafone-cash-invalid'),
        text: ParentPaymentMethodsText.vodafoneCashInvalid,
        color: AppColors.error,
      );
    } else {
      body = _DestinationValue(
        key: const Key('vodafone-cash-destination'),
        label: ParentPaymentMethodsText.walletLabel,
        value: AcademyPaymentDestinations.normalizeVodafoneCash(raw),
      );
    }
    return _MethodCard(
      title: ParentPaymentMethodsText.vodafoneCashTitle,
      icon: Icons.account_balance_wallet_outlined,
      child: body,
    );
  }
}

class _InstapayCard extends StatelessWidget {
  final String destination;
  final PaymentLinkOpener openLink;

  const _InstapayCard({required this.destination, required this.openLink});

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await openLink(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text(ParentPaymentMethodsText.linkOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = destination.trim();
    final kind = AcademyPaymentDestinations.instapayKind(raw);
    final Widget body;
    if (raw.isEmpty) {
      body = const _Notice(
        key: Key('instapay-unset'),
        text: ParentPaymentMethodsText.instapayUnset,
        color: AppColors.textSecondary,
      );
    } else if (kind == null) {
      body = const _Notice(
        key: Key('instapay-invalid'),
        text: ParentPaymentMethodsText.instapayInvalid,
        color: AppColors.error,
      );
    } else if (kind == InstapayDestinationKind.address) {
      body = _DestinationValue(
        key: const Key('instapay-destination'),
        label: ParentPaymentMethodsText.instapayAddressLabel,
        value: AcademyPaymentDestinations.normalizeInstapay(raw),
      );
    } else {
      final uri = AcademyPaymentDestinations.instapayLinkUri(raw)!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DestinationValue(
            key: const Key('instapay-destination'),
            label: ParentPaymentMethodsText.instapayLinkLabel,
            value: raw,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const Key('instapay-open-link'),
            onPressed: () => _open(context, uri),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text(ParentPaymentMethodsText.openInstapayLink),
          ),
        ],
      );
    }
    return _MethodCard(
      title: ParentPaymentMethodsText.instapayTitle,
      icon: Icons.swap_horiz_rounded,
      child: body,
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _MethodCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DestinationValue extends StatelessWidget {
  final String label;
  final String value;

  const _DestinationValue({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'نسخ $label',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(content: Text(ParentPaymentMethodsText.copied)),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? action;

  const _Notice({
    super.key,
    required this.text,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(color: color, height: 1.4),
        ),
        if (action != null)
          Align(alignment: AlignmentDirectional.centerStart, child: action),
      ],
    );
  }
}
