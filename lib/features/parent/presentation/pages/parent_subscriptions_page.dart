import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_payment_proof.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentSubscriptionsPage extends StatefulWidget {
  final bool embedded;

  const ParentSubscriptionsPage({super.key, this.embedded = false});

  @override
  State<ParentSubscriptionsPage> createState() =>
      _ParentSubscriptionsPageState();
}

class _ParentSubscriptionsPageState extends State<ParentSubscriptionsPage> {
  int _filter = 0;

  static const _filters = [
    (0, 'الكل'),
    (1, 'مدفوع'),
    (2, 'مستحق'),
    (3, 'متأخر'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadPaymentsEvent(auth.user.uid));
    context.read<ParentBloc>().add(LoadWalletEvent(auth.user.uid));
  }

  void _comingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('قريباً')));
  }

  Future<void> _startExternalPayThenProof(PaymentEntity payment) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      builder: (ctx) => _ExternalPaySheet(payment: payment),
    );
    if (proceed != true || !mounted) return;
    await _pickAndSubmitProof(payment);
  }

  Future<void> _pickAndSubmitProof(PaymentEntity payment) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: false,
    );
    if (!mounted) return;
    final path = result?.files.single.path?.trim();
    if (path == null || path.isEmpty) return;

    context.read<ParentBloc>().add(
      SubmitPaymentProofEvent(
        parentId: auth.user.uid,
        paymentId: payment.id,
        localFilePath: path,
      ),
    );
  }

  Future<void> _uploadForUnpaid(List<PaymentEntity> payments) async {
    final unpaid = payments
        .where((p) => p.status != PaymentStatus.paid)
        .toList();
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مستحقات لرفع إيصال لها')),
      );
      return;
    }
    if (unpaid.length == 1) {
      await _startExternalPayThenProof(unpaid.first);
      return;
    }
    final selected = await showModalBottomSheet<PaymentEntity>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'اختر الاشتراك',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final payment in unpaid)
                ListTile(
                  title: Text(
                    context.read<ParentBloc>().state.childDisplayName(
                      payment.studentId,
                    ),
                  ),
                  subtitle: Text(parentMoneyLabel(payment.amount)),
                  onTap: () => Navigator.pop(ctx, payment),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    await _startExternalPayThenProof(selected);
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<ParentBloc, ParentState>(
        listenWhen: (p, c) =>
        p.walletPayStatus != c.walletPayStatus ||
            p.walletPayError != c.walletPayError ||
            p.paymentProofStatus != c.paymentProofStatus ||
            p.paymentProofError != c.paymentProofError,
        listener: (context, state) {
          if (state.walletPayStatus == SubmissionStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.walletPayError ?? 'تعذر الدفع من المحفظة',
                ),
              ),
            );
            context.read<ParentBloc>().add(const ResetWalletPayEvent());
          } else if (state.walletPayStatus == SubmissionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم سداد المستحق من المحفظة')),
            );
            context.read<ParentBloc>().add(const ResetWalletPayEvent());
          }

          if (state.paymentProofStatus == SubmissionStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.paymentProofError ?? 'تعذر رفع إثبات الدفع',
                ),
              ),
            );
            context.read<ParentBloc>().add(const ResetPaymentProofEvent());
          } else if (state.paymentProofStatus == SubmissionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم إرسال إثبات الدفع للمراجعة — الاعتماد من الإدارة',
                ),
              ),
            );
            context.read<ParentBloc>().add(const ResetPaymentProofEvent());
          }
        },
        buildWhen: (p, c) =>
        p.paymentsStatus != c.paymentsStatus ||
            p.payments != c.payments ||
            p.paymentsError != c.paymentsError ||
            p.wallet != c.wallet ||
            p.walletStatus != c.walletStatus ||
            p.walletPayStatus != c.walletPayStatus ||
            p.paymentProofStatus != c.paymentProofStatus ||
            p.paymentProofPaymentId != c.paymentProofPaymentId ||
            p.childrenSnapshots != c.childrenSnapshots,
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ParentState state) {
    if (state.paymentsStatus == SectionStatus.initial ||
        state.paymentsStatus == SectionStatus.loading) {
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(child: ParentListCardsSkeleton()),
        ],
      );
    }

    if (state.paymentsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.paymentsError ?? 'تعذر تحميل الاشتراكات',
        onRetry: _load,
      );
    }

    final filteredLists = [
      state.payments,
      state.payments.where((p) => p.status == PaymentStatus.paid).toList(),
      state.payments.where((p) => p.status == PaymentStatus.due).toList(),
      state.payments.where((p) => p.status == PaymentStatus.overdue).toList(),
    ];
    final visible = filteredLists[_filter];
    final total = state.payments.fold<double>(0, (s, p) => s + p.amount);
    final paid = state.payments
        .where((p) => p.status == PaymentStatus.paid)
        .fold<double>(0, (s, p) => s + p.amount);
    final remaining = (total - paid) < 0 ? 0.0 : (total - paid);
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final childrenCaption = parentPaymentsChildrenCaption(
      payments: state.payments,
      nameFor: state.childDisplayName,
    );
    final walletBalance = state.wallet?.balance ?? 0.0;
    final proofBusy = state.paymentProofStatus == SubmissionStatus.submitting;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => _load(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SizedBox(height: widget.embedded ? 300 : 230),
                  ),
                ),
                Column(
                  children: [
                    _PaymentsHeader(
                      embedded: widget.embedded,
                      onHistory: _comingSoon,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _MonthlySummaryCard(
                        total: total,
                        paid: paid,
                        remaining: remaining,
                        progress: progress,
                        childrenCaption: childrenCaption,
                        walletBalance: walletBalance,
                        walletLoaded:
                        state.walletStatus == SectionStatus.loaded ||
                            state.wallet != null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusXL),
                  topRight: Radius.circular(AppSizes.radiusXL),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterRow(
                      filters: _filters,
                      selected: _filter,
                      onChanged: (index) => setState(() => _filter = index),
                    ),
                    const SizedBox(height: 14),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 16),
                        child: ParentEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'لا توجد مدفوعات في هذا التصنيف',
                          message:
                          'ستظهر هنا اشتراكات أبنائك عند إضافتها من الأكاديمية.',
                        ),
                      )
                    else
                      ...visible.map(
                            (payment) =>
                            _PaymentCard(
                              payment: payment,
                              studentName: state.childDisplayName(payment
                                  .studentId),
                              paying:
                              state.walletPayStatus ==
                                  SubmissionStatus.submitting,
                              uploadingProof:
                              proofBusy &&
                                  state.paymentProofPaymentId == payment.id,
                              onPay: () {
                                final auth = context
                                    .read<AuthBloc>()
                                    .state;
                                if (auth is! AuthAuthenticated) return;
                                context.read<ParentBloc>().add(
                                  PayPaymentFromWalletEvent(
                                    parentId: auth.user.uid,
                                    paymentId: payment.id,
                                  ),
                                );
                              },
                              onUploadReceipt: proofBusy
                                  ? () {}
                                  : () => _startExternalPayThenProof(payment),
                            ),
                      ),
                    const SizedBox(height: 12),
                    _UploadReceiptCard(
                      onTap: proofBusy
                          ? () {}
                          : () => _uploadForUnpaid(state.payments),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalPaySheet extends StatelessWidget {
  final PaymentEntity payment;

  const _ExternalPaySheet({required this.payment});

  Future<void> _openDestination(BuildContext context) async {
    final dest = ParentPaymentProofContract.transferDestination.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم تُضبط بيانات التحويل بعد — اتبع تعليمات الأكاديمية',
          ),
        ),
      );
      return;
    }
    final tel = dest.startsWith('tel:') ? dest : 'tel:$dest';
    final uri = Uri.tryParse(tel);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final amount = parentMoneyLabel(payment.amount);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الدفع عبر فودافون كاش',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '١) ادفع المبلغ خارج التطبيق.\n'
                  '٢) التقط لقطة شاشة لإثبات الدفع.\n'
                  '٣) ارفع اللقطة هنا للمراجعة.\n'
                  'رفع الإيصال لا يعني اعتماد الدفع تلقائياً — الإدارة تعتمد بعد المراجعة.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'المبلغ: $amount',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ المبلغ',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: payment.amount.toStringAsFixed(0)),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ المبلغ')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openDestination(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('فتح طريقة الدفع الخارجية'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('اخترتُ الملف / لقطة الشاشة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, 46),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لاحقاً'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsHeader extends StatelessWidget {
  final bool embedded;
  final VoidCallback onHistory;

  const _PaymentsHeader({
    required this.embedded,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery
            .paddingOf(context)
            .top + (embedded ? 4 : 0),
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          if (!embedded)
            _HeaderIconButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              'إدارة الاشتراكات',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: InkWell(
              onTap: onHistory,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'سجل',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimaryOverlay,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.onPrimary),
        ),
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final double total;
  final double paid;
  final double remaining;
  final double progress;
  final String childrenCaption;
  final double walletBalance;
  final bool walletLoaded;

  const _MonthlySummaryCard({
    required this.total,
    required this.paid,
    required this.remaining,
    required this.progress,
    required this.childrenCaption,
    required this.walletBalance,
    required this.walletLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryOverlay,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الإجمالي الشهري',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            parentMoneyLabel(total),
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 32,
              height: 1.15,
            ),
          ),
          if (childrenCaption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              childrenCaption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onPrimaryMuted,
              ),
            ),
          ],
          if (walletLoaded) ...[
            const SizedBox(height: 10),
            Text(
              'رصيد المحفظة: ${parentMoneyLabel(walletBalance)}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.onPrimary.withValues(alpha: 0.22),
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${parentMoneyLabel(paid)} مدفوع',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              Text(
                '${parentMoneyLabel(remaining)} متبقي',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<(int, String)> filters;
  final int selected;
  final ValueChanged<int> onChanged;

  const _FilterRow({
    required this.filters,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in filters) ...[
            _FilterChip(
              label: entry.$2,
              selected: selected == entry.$1,
              onTap: () => onChanged(entry.$1),
            ),
            if (entry != filters.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentEntity payment;
  final String studentName;
  final bool paying;
  final bool uploadingProof;
  final VoidCallback onPay;
  final VoidCallback onUploadReceipt;

  const _PaymentCard({
    required this.payment,
    required this.studentName,
    required this.paying,
    required this.uploadingProof,
    required this.onPay,
    required this.onUploadReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == PaymentStatus.paid;
    final isOverdue = payment.status == PaymentStatus.overdue;
    final awaitingReview = payment.hasProofAwaitingReview;
    final accent = isPaid
        ? AppColors.success
        : awaitingReview
        ? AppColors.info
        : isOverdue
        ? AppColors.error
        : AppColors.warning;
    final title = '$studentName — ${parentPaymentPeriodLabel(payment.dueDate)}';
    final subtitle = _statusSubtitle(payment);
    final method = payment.method?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusIconBox(
                  icon: isPaid
                      ? Icons.check_rounded
                      : awaitingReview
                      ? Icons.hourglass_top_rounded
                      : Icons.warning_amber_rounded,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(height: 1.25),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (method != null &&
                          method.isNotEmpty &&
                          (isPaid || awaitingReview)) ...[
                        const SizedBox(height: 2),
                        Text(
                          method == ParentPaymentProofContract.externalMethod
                              ? 'فودافون كاش'
                              : method,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isPaid || awaitingReview)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppColors.successBg
                              : AppColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Text(
                          isPaid ? 'مؤكد' : 'قيد المراجعة',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isPaid ? AppColors.success : AppColors.info,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isPaid || awaitingReview) const SizedBox(height: 6),
                    Text(
                      parentMoneyLabel(payment.amount),
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isPaid
                            ? AppColors.textPrimary
                            : isOverdue && !awaitingReview
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploadingProof ? null : onUploadReceipt,
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(
                        uploadingProof
                            ? 'جاري الرفع...'
                            : awaitingReview
                            ? 'تحديث الإيصال'
                            : 'رفع إيصال',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: paying || uploadingProof ? null : onPay,
                      icon: const Icon(Icons.account_balance_wallet_outlined,
                          size: 18),
                      label: Text(paying ? 'جاري السداد...' : 'سداد الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusSubtitle(PaymentEntity payment) {
    if (payment.hasProofAwaitingReview) {
      return payment.proofSubmittedAt == null
          ? 'إثبات مرسل — بانتظار اعتماد الإدارة'
          : 'إثبات مرسل ${formatDateDmy(payment.proofSubmittedAt!)}';
    }
    return switch (payment.status) {
      PaymentStatus.paid =>
      payment.paidAt == null
          ? 'مدفوع'
          : 'مدفوع ${formatDateDmy(payment.paidAt!)}',
      PaymentStatus.due => 'مستحق ${formatDateDmy(payment.dueDate)}',
      PaymentStatus.overdue => 'متأخر — لم يُسدّد بعد',
    };
  }
}

class _StatusIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusIconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _UploadReceiptCard extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadReceiptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'رفع إيصال الدفع',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'صورة أو PDF، حتى ١٠ ميجا — للمراجعة وليس اعتماداً تلقائياً',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('اختيار ملف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
