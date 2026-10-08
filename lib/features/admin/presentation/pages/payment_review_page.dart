import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../bloc/payment_review_bloc.dart';

/// P0-03 — pending payment-proof review (Admin: all; Supervisor: supervised
/// students). Proof image + invoice context; approve / reject / partial via
/// the authoritative `reviewPaymentProof` callable.
class PaymentReviewPage extends StatelessWidget {
  final bool isAdmin;

  const PaymentReviewPage({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';
    return BlocProvider<PaymentReviewBloc>(
      create: (_) =>
          sl<PaymentReviewBloc>()
            ..add(LoadPendingProofsEvent(reviewerUid: uid, isAdmin: isAdmin)),
      child: BlocConsumer<PaymentReviewBloc, PaymentReviewState>(
        listenWhen: (p, c) =>
            p.submissionStatus != c.submissionStatus &&
            (c.submissionStatus == SubmissionStatus.success ||
                c.submissionStatus == SubmissionStatus.error),
        listener: (context, state) {
          final message = state.message ?? '';
          if (message.isNotEmpty) {
            if (state.submissionStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, message);
            } else {
              AppSnackBar.showError(context, message);
            }
          }
          context.read<PaymentReviewBloc>().add(
            const ClearPaymentReviewMessageEvent(),
          );
        },
        builder: (context, state) {
          final bloc = context.read<PaymentReviewBloc>();
          void reload() => bloc.add(
            LoadPendingProofsEvent(reviewerUid: uid, isAdmin: isAdmin),
          );
          final Widget body = switch (state.status) {
            SectionStatus.initial ||
            SectionStatus.loading => const AppLoadingWidget(),
            SectionStatus.error => AppErrorWidget(
              message: state.error ?? 'تعذر تحميل الإيصالات',
              onRetry: reload,
            ),
            SectionStatus.loaded when state.items.isEmpty => AppEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'لا توجد إيصالات بانتظار المراجعة',
              message: isAdmin
                  ? 'ستظهر هنا إيصالات أولياء الأمور فور رفعها'
                  : 'ستظهر هنا إيصالات طلاب حلقاتك فور رفعها',
              actionLabel: 'تحديث',
              onAction: reload,
            ),
            SectionStatus.loaded => RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ProofCard(
                  item: state.items[i],
                  busy:
                      state.submissionStatus == SubmissionStatus.submitting &&
                      state.activePaymentId == state.items[i].paymentId,
                ),
              ),
            ),
          };
          return AppSubpageScaffold(title: 'مراجعة المدفوعات', body: body);
        },
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  final PaymentReviewItem item;
  final bool busy;

  const _ProofCard({required this.item, required this.busy});

  String _amount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _date(DateTime? d) => d == null
      ? '—'
      : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _decide(
    BuildContext context,
    PaymentReviewDecision decision,
  ) async {
    final result = await showDialog<(String?, double?)>(
      context: context,
      builder: (_) => _DecisionDialog(item: item, decision: decision),
    );
    if (result == null || !context.mounted) return;
    context.read<PaymentReviewBloc>().add(
      SubmitPaymentReviewEvent(
        item: item,
        decision: decision,
        notes: result.$1,
        amountPaidConfirmed: result.$2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = item.currency.isEmpty ? '' : ' ${item.currency}';
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.studentName.isEmpty ? item.studentId : item.studentName,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              const AppStatusChip(
                label: 'بانتظار المراجعة',
                tone: AppStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'قيمة الفاتورة: ${_amount(item.amount)}$currency'
            '${item.periodKey.isEmpty ? '' : ' · الفترة: ${item.periodKey}'}',
            style: AppTextStyles.bodyMedium,
          ),
          Text(
            'الاستحقاق: ${_date(item.dueDate)} · رفع الإيصال: ${_date(item.proofSubmittedAt)}',
            style: AppTextStyles.labelSmall,
          ),
          const SizedBox(height: 12),
          if (item.hasProofImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(item.proofDownloadUrl!),
                    ),
                  ),
                ),
                child: Image.network(
                  item.proofDownloadUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('تعذر تحميل صورة الإيصال')),
                  ),
                ),
              ),
            )
          else
            Text(
              'لا توجد صورة إيصال مرفقة',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          const SizedBox(height: 12),
          if (busy)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton(
                  onPressed: () =>
                      _decide(context, PaymentReviewDecision.approve),
                  child: Text(PaymentReviewDecision.approve.label),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _decide(context, PaymentReviewDecision.partial),
                  child: Text(PaymentReviewDecision.partial.label),
                ),
                TextButton(
                  onPressed: () =>
                      _decide(context, PaymentReviewDecision.reject),
                  child: Text(PaymentReviewDecision.reject.label),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  final PaymentReviewItem item;
  final PaymentReviewDecision decision;

  const _DecisionDialog({required this.item, required this.decision});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    double? confirmed;
    if (widget.decision == PaymentReviewDecision.partial) {
      confirmed = double.tryParse(_amount.text.trim());
      final error = validatePartialAmount(
        invoiceAmount: widget.item.amount,
        confirmed: confirmed,
      );
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    final notes = _notes.text.trim();
    Navigator.pop(context, (notes.isEmpty ? null : notes, confirmed));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.decision.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.decision == PaymentReviewDecision.partial) ...[
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'المبلغ المؤكد'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _notes,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(onPressed: _confirm, child: const Text('تأكيد')),
      ],
    );
  }
}
