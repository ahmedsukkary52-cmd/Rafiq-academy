import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/parent_entities.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final body = BlocConsumer<ParentBloc, ParentState>(
      listenWhen: (p, c) =>
          p.walletPayStatus != c.walletPayStatus ||
          p.walletPayError != c.walletPayError,
      listener: (context, state) {
        if (state.walletPayStatus == SubmissionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.walletPayError ?? 'تعذر الدفع من المحفظة'),
            ),
          );
          context.read<ParentBloc>().add(const ResetWalletPayEvent());
        } else if (state.walletPayStatus == SubmissionStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم سداد المستحق من المحفظة')),
          );
          context.read<ParentBloc>().add(const ResetWalletPayEvent());
        }
      },
      buildWhen: (p, c) =>
          p.paymentsStatus != c.paymentsStatus ||
          p.payments != c.payments ||
          p.paymentsError != c.paymentsError ||
          p.wallet != c.wallet ||
          p.walletStatus != c.walletStatus ||
          p.walletPayStatus != c.walletPayStatus ||
          p.walletPayError != c.walletPayError,
      builder: (context, state) {
        if (state.paymentsStatus == SectionStatus.initial ||
            state.paymentsStatus == SectionStatus.loading) {
          return const ParentListCardsSkeleton();
        }
        if (state.paymentsStatus == SectionStatus.error) {
          return AppErrorWidget(
            message: state.paymentsError ?? 'تعذر تحميل الاشتراكات',
            onRetry: _load,
          );
        }

        final filters = [
          state.payments,
          state.payments.where((p) => p.status == PaymentStatus.paid).toList(),
          state.payments.where((p) => p.status == PaymentStatus.due).toList(),
          state.payments
              .where((p) => p.status == PaymentStatus.overdue)
              .toList(),
        ];
        final visible = filters[_filter];
        final total = state.payments.fold<double>(0, (s, p) => s + p.amount);
        final paid = state.payments
            .where((p) => p.status == PaymentStatus.paid)
            .fold<double>(0, (s, p) => s + p.amount);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الإجمالي',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onPrimaryMuted,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      '${total.toStringAsFixed(0)} ريال',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.onPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'رصيد المحفظة ${(state.wallet?.balance ?? 0).toStringAsFixed(0)} ريال',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onPrimaryMuted,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      'مدفوع ${paid.toStringAsFixed(0)} — المتبقي ${(total - paid).toStringAsFixed(0)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onPrimaryMuted,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const [
                    (0, 'الكل'),
                    (1, 'مدفوع'),
                    (2, 'مستحق'),
                    (3, 'متأخر'),
                  ])
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: ParentEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'لا توجد مدفوعات في هذا التصنيف',
                    message:
                        'الدفع يتم عبر محفظة ولي الأمر. لا توجد عملية شحن من هذا التطبيق.',
                  ),
                )
              else
                ...visible.map(
                  (payment) => _PaymentCard(
                    payment,
                    paying: state.walletPayStatus == SubmissionStatus.submitting,
                    onPay: () {
                      final auth = context.read<AuthBloc>().state;
                      if (auth is! AuthAuthenticated) return;
                      context.read<ParentBloc>().add(
                        PayPaymentFromWalletEvent(
                          parentId: auth.user.uid,
                          paymentId: payment.id,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('إدارة الاشتراكات'),
            automaticallyImplyLeading: false,
          ),
          body: body,
        ),
      );
    }

    return ParentSubpageScaffold(title: 'إدارة الاشتراكات', body: body);
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentEntity payment;
  final bool paying;
  final VoidCallback onPay;

  const _PaymentCard(this.payment, {required this.paying, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == PaymentStatus.paid;
    final isOverdue = payment.status == PaymentStatus.overdue;
    final statusLabel = switch (payment.status) {
      PaymentStatus.paid => 'مدفوع',
      PaymentStatus.due => 'مستحق',
      PaymentStatus.overdue => 'متأخر',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(0)} ريال',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: isOverdue ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDateDmy(payment.dueDate),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              statusLabel,
              style: AppTextStyles.titleMedium.copyWith(
                color: isPaid
                    ? AppColors.success
                    : isOverdue
                    ? AppColors.error
                    : AppColors.warning,
              ),
              textAlign: TextAlign.right,
            ),
            if (!isPaid) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: paying ? null : onPay,
                child: Text(paying ? 'جاري الدفع...' : 'الدفع عبر المحفظة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
