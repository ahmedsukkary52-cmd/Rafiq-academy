import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/repositories/parent_repository.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

enum _PaymentFilter { all, awaiting, reviewed }

/// Supervisor payment submissions — review external-pay proofs.
class SupervisorPaymentsPage extends StatefulWidget {
  const SupervisorPaymentsPage({super.key});

  @override
  State<SupervisorPaymentsPage> createState() => _SupervisorPaymentsPageState();
}

class _SupervisorPaymentsPageState extends State<SupervisorPaymentsPage> {
  _PaymentFilter _filter = _PaymentFilter.all;
  Map<String, String> _names = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<String> _studentIds(SupervisorState state) {
    final ids = <String>{};
    for (final h in state.halaqat) {
      ids.addAll(h.studentIds);
    }
    return ids.toList();
  }

  Future<void> _resolveNames(List<String> ids) async {
    if (ids.isEmpty) return;
    final result = await sl<SupervisorRepository>().getUserDisplayNames(ids);
    if (!mounted) return;
    result.fold((_) {}, (map) {
      setState(() => _names = {..._names, ...map});
    });
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final bloc = context.read<SupervisorBloc>();
    final ids = _studentIds(bloc.state);
    bloc.add(
      LoadSupervisedPaymentsEvent(supervisorId: auth.user.uid, studentIds: ids),
    );
    _resolveNames(ids);
  }

  List<PaymentEntity> _visible(List<PaymentEntity> all) {
    return switch (_filter) {
      _PaymentFilter.awaiting =>
        all.where((p) => p.hasProofAwaitingReview).toList(),
      _PaymentFilter.reviewed =>
        all.where((p) => p.hasSupervisorReview).toList(),
      _PaymentFilter.all => all,
    };
  }

  String _money(double v) => '${v.toStringAsFixed(0)} ر.س';

  String _period(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}';

  String _reviewLabel(PaymentEntity p) {
    if (p.hasProofAwaitingReview) return 'بانتظار المراجعة';
    return switch (p.reviewStatus) {
      ParentPaymentProofContract.approved => 'مقبول',
      ParentPaymentProofContract.rejected => 'مرفوض',
      ParentPaymentProofContract.partial => 'جزئي',
      _ => p.status == PaymentStatus.paid ? 'مدفوع' : 'بدون إثبات',
    };
  }

  Color _reviewColor(PaymentEntity p) {
    if (p.hasProofAwaitingReview) return AppColors.warning;
    return switch (p.reviewStatus) {
      ParentPaymentProofContract.approved => AppColors.success,
      ParentPaymentProofContract.rejected => AppColors.error,
      ParentPaymentProofContract.partial => AppColors.secondaryDeep,
      _ => AppColors.textSecondary,
    };
  }

  Future<void> _openReview(PaymentEntity payment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<SupervisorBloc>(),
          child: _PaymentReviewPage(
            payment: payment,
            studentName: _names[payment.studentId] ?? payment.studentId,
            parentName: _names[payment.parentId] ?? payment.parentId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.reviewPaymentStatus != c.reviewPaymentStatus ||
          p.payments != c.payments,
      listener: (context, state) {
        if (state.payments.isNotEmpty) {
          final ids = <String>{
            for (final p in state.payments) ...[p.studentId, p.parentId],
          }.toList();
          _resolveNames(ids);
        }
        if (state.reviewPaymentStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم حفظ نتيجة المراجعة');
          context.read<SupervisorBloc>().add(const ResetReviewPaymentEvent());
        } else if (state.reviewPaymentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.reviewPaymentError ?? 'تعذر حفظ المراجعة',
          );
          context.read<SupervisorBloc>().add(const ResetReviewPaymentEvent());
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'المدفوعات',
        actions: [
          IconButton(
            tooltip: 'تقرير المراجعات',
            onPressed: () {
              final payments = context.read<SupervisorBloc>().state.payments;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _PaymentsReportPage(payments: payments, names: _names),
                ),
              );
            },
            icon: const Icon(Icons.summarize_outlined),
          ),
        ],
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.paymentsStatus != c.paymentsStatus ||
              p.payments != c.payments ||
              p.halaqat != c.halaqat,
          builder: (context, state) {
            if (state.paymentsStatus == SectionStatus.loading ||
                state.paymentsStatus == SectionStatus.initial) {
              return const SupervisorPaymentsListSkeleton();
            }
            if (state.paymentsStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.paymentsError ?? 'تعذر التحميل',
                onRetry: _load,
              );
            }

            final all = state.payments;
            final awaiting = all.where((p) => p.hasProofAwaitingReview).length;
            final reviewed = all.where((p) => p.hasSupervisorReview).length;
            final visible = _visible(all);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KpiChip(
                          value: '$awaiting',
                          label: 'بانتظار المراجعة',
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiChip(
                          value: '$reviewed',
                          label: 'تمت مراجعتها',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiChip(
                          value: '${all.length}',
                          label: 'إجمالي السجلات',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _PaymentFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _PaymentFilter.all => 'الكل',
                                _PaymentFilter.awaiting => 'بانتظار المراجعة',
                                _PaymentFilter.reviewed => 'مُراجعة',
                              }),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    AppCard(
                      child: Text(
                        'لا توجد مدفوعات مطابقة',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  else
                    ...visible.map((p) {
                      final name = _names[p.studentId] ?? p.studentId;
                      final color = _reviewColor(p);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => _openReview(p),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${_money(p.amount)} · ${_period(p.dueDate)}',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (p.method != null)
                                      Text(
                                        p.method ==
                                                ParentPaymentProofContract
                                                    .externalMethod
                                            ? 'فودافون كاش (خارجي)'
                                            : p.method!,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  _reviewLabel(p),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _KpiChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentReviewPage extends StatefulWidget {
  final PaymentEntity payment;
  final String studentName;
  final String parentName;

  const _PaymentReviewPage({
    required this.payment,
    required this.studentName,
    required this.parentName,
  });

  @override
  State<_PaymentReviewPage> createState() => _PaymentReviewPageState();
}

class _PaymentReviewPageState extends State<_PaymentReviewPage> {
  final _notesCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();
  PaymentReviewDecision _decision = PaymentReviewDecision.approved;

  @override
  void initState() {
    super.initState();
    _paidCtrl.text = widget.payment.amount.toStringAsFixed(0);
    _remainingCtrl.text = '0';
    _notesCtrl.text = widget.payment.reviewNotes ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _paidCtrl.dispose();
    _remainingCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final paid = double.tryParse(_paidCtrl.text.trim());
    final remaining = double.tryParse(_remainingCtrl.text.trim());
    if (_decision == PaymentReviewDecision.partial &&
        (remaining == null || remaining < 0)) {
      AppSnackBar.showInfo(context, 'أدخل المبلغ المتبقي');
      return;
    }

    context.read<SupervisorBloc>().add(
      ReviewPaymentProofEvent(
        PaymentReviewParams(
          supervisorId: auth.user.uid,
          paymentId: widget.payment.id,
          decision: _decision,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          amountPaidConfirmed: paid,
          remainingAmount: _decision == PaymentReviewDecision.partial
              ? remaining
              : (_decision == PaymentReviewDecision.approved ? 0 : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final proofUrl = p.proofDownloadUrl?.trim();

    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (a, b) => a.reviewPaymentStatus != b.reviewPaymentStatus,
      listener: (context, state) {
        if (state.reviewPaymentStatus == SubmissionStatus.success) {
          Navigator.of(context).maybePop();
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'مراجعة إثبات الدفع',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (a, b) => a.reviewPaymentStatus != b.reviewPaymentStatus,
          builder: (context, state) {
            final busy =
                state.reviewPaymentStatus == SubmissionStatus.submitting;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(label: 'الطالب', value: widget.studentName),
                      _InfoRow(label: 'ولي الأمر', value: widget.parentName),
                      _InfoRow(
                        label: 'المبلغ المطلوب',
                        value: '${p.amount.toStringAsFixed(0)} ر.س',
                      ),
                      _InfoRow(
                        label: 'الفترة',
                        value:
                            '${p.dueDate.year}/${p.dueDate.month.toString().padLeft(2, '0')}',
                      ),
                      _InfoRow(
                        label: 'طريقة الدفع',
                        value:
                            p.method ==
                                ParentPaymentProofContract.externalMethod
                            ? 'فودافون كاش (خارج التطبيق)'
                            : (p.method ?? '—'),
                      ),
                      if (p.proofSubmittedAt != null)
                        _InfoRow(
                          label: 'وقت الإرسال',
                          value: p.proofSubmittedAt!.toLocal().toString(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'صورة الإثبات',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (proofUrl == null || proofUrl.isEmpty)
                  const AppCard(child: Text('لا توجد صورة إثبات مرفقة'))
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(
                        proofUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceGrey,
                          alignment: Alignment.center,
                          child: const Text('تعذر عرض الصورة'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'نتيجة المراجعة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in PaymentReviewDecision.values)
                      ChoiceChip(
                        label: Text(switch (d) {
                          PaymentReviewDecision.approved => 'قبول',
                          PaymentReviewDecision.rejected => 'رفض',
                          PaymentReviewDecision.partial => 'جزئي',
                        }),
                        selected: _decision == d,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => _decision = d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paidCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع المؤكد',
                  ),
                ),
                if (_decision == PaymentReviewDecision.partial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remainingCtrl,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المتبقي',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  enabled: !busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات المراجعة',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(busy ? 'جاري الحفظ…' : 'حفظ نتيجة المراجعة'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsReportPage extends StatelessWidget {
  final List<PaymentEntity> payments;
  final Map<String, String> names;

  const _PaymentsReportPage({required this.payments, required this.names});

  @override
  Widget build(BuildContext context) {
    final reviewed = payments.where((p) => p.hasSupervisorReview).toList();
    final approved = reviewed
        .where((p) => p.reviewStatus == ParentPaymentProofContract.approved)
        .toList();
    final rejected = reviewed
        .where((p) => p.reviewStatus == ParentPaymentProofContract.rejected)
        .toList();
    final partial = reviewed
        .where((p) => p.reviewStatus == ParentPaymentProofContract.partial)
        .toList();
    final approvedTotal = approved.fold<double>(
      0,
      (s, p) => s + (p.amountPaidConfirmed ?? p.amount),
    );

    return SupervisorSubpageScaffold(
      title: 'تقرير المراجعات',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          AppCard(
            child: Column(
              children: [
                _InfoRow(label: 'عمليات مُراجعة', value: '${reviewed.length}'),
                _InfoRow(label: 'مقبولة', value: '${approved.length}'),
                _InfoRow(label: 'مرفوضة', value: '${rejected.length}'),
                _InfoRow(label: 'جزئية', value: '${partial.length}'),
                _InfoRow(
                  label: 'إجمالي المقبول',
                  value: '${approvedTotal.toStringAsFixed(0)} ر.س',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'التفاصيل',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (reviewed.isEmpty)
            const AppCard(child: Text('لا توجد مراجعات بعد'))
          else
            ...reviewed.map((p) {
              final name = names[p.studentId] ?? p.studentId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${p.reviewStatus} · ${(p.amountPaidConfirmed ?? p.amount).toStringAsFixed(0)} ر.س',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((p.reviewNotes ?? '').isNotEmpty)
                        Text(p.reviewNotes!),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
