import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/payment_review_amount_panel.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../parent/presentation/widgets/payment_proof_image.dart';
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
                itemBuilder: (context, i) {
                  final item = state.items[i];
                  final submitting =
                      state.submissionStatus == SubmissionStatus.submitting;
                  final own = state.activePaymentId == item.paymentId;
                  return _ProofCard(
                    key: ValueKey(item.paymentId),
                    item: item,
                    busy: submitting && own,
                    otherBusy: submitting && !own,
                    unresolved: state.unresolvedFor(item),
                  );
                },
              ),
            ),
          };
          return AppSubpageScaffold(title: 'مراجعة المدفوعات', body: body);
        },
      ),
    );
  }
}

class _ProofCard extends StatefulWidget {
  final PaymentReviewItem item;
  final bool busy;

  /// Another payment's review is in flight: decisions here are blocked.
  final bool otherBusy;

  /// This item's decision whose outcome is still unknown.
  final PaymentReviewCommand? unresolved;

  const _ProofCard({
    super.key,
    required this.item,
    required this.busy,
    this.otherBusy = false,
    this.unresolved,
  });

  @override
  State<_ProofCard> createState() => _ProofCardState();
}

class _ProofCardState extends State<_ProofCard> {
  /// Storage path whose image is currently displayed; null while loading or
  /// after a failure.
  String? _loadedProofPath;

  PaymentReviewItem get item => widget.item;
  bool get busy => widget.busy;
  bool get otherBusy => widget.otherBusy;
  PaymentReviewCommand? get unresolved => widget.unresolved;

  /// Decisions require the image of the current proof to be on screen.
  bool get _proofLoaded =>
      item.hasProofMetadata && _loadedProofPath == item.proofStoragePath;

  void _onProofLoadedChanged(bool loaded) {
    setState(() => _loadedProofPath = loaded ? item.proofStoragePath : null);
  }

  String _amount(double v) => formatMoneyAmount(v);

  String _describe(PaymentReviewCommand command, String currency) {
    final decision = PaymentReviewDecision.values.firstWhere(
      (d) => d.wire == command.decision,
    );
    final amount = command.amountMinorUnits;
    final mode = command.amountMode;
    return [
      decision.label,
      if (mode != null && amount != null)
        '${mode.label}: ${formatMinorUnits(amount)}$currency',
      if (command.notes.isNotEmpty) 'ملاحظات: ${command.notes}',
    ].join(' · ');
  }

  void _retry(BuildContext context, PaymentReviewCommand command) {
    if (!_proofLoaded) return;
    final bloc = context.read<PaymentReviewBloc>();
    if (bloc.state.submissionStatus == SubmissionStatus.submitting) {
      AppSnackBar.showInfo(context, kPaymentReviewBusyMessage);
      return;
    }
    bloc.add(SubmitPaymentReviewEvent.retry(item, command));
  }

  String _date(DateTime? d) => d == null
      ? '—'
      : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _decide(
    BuildContext context,
    PaymentReviewDecision decision,
  ) async {
    if (!_proofLoaded) return;
    final result = await showDialog<_DecisionDraft>(
      context: context,
      builder: (_) => _DecisionDialog(item: item, decision: decision),
    );
    if (result == null || !context.mounted || !_proofLoaded) return;
    final bloc = context.read<PaymentReviewBloc>();
    if (bloc.state.submissionStatus == SubmissionStatus.submitting) {
      AppSnackBar.showInfo(context, kPaymentReviewBusyMessage);
      return;
    }
    bloc.add(
      SubmitPaymentReviewEvent(
        item: item,
        decision: decision,
        notes: result.notes,
        amountMode: result.amountMode,
        amountMinorUnits: result.amountMinorUnits,
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
          if (item.amountSnapshot.error case final amountError?)
            Text(
              amountError,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            )
          else if (item.amountSnapshot.previous > 0)
            Text(
              'المؤكد سابقاً: ${formatMinorUnits(item.amountSnapshot.previous)}$currency'
              ' · المتبقي: ${formatMinorUnits(item.amountSnapshot.remaining)}$currency',
              style: AppTextStyles.labelSmall,
            ),
          Text(
            'الاستحقاق: ${_date(item.dueDate)} · رفع الإيصال: ${_date(item.proofSubmittedAt)}',
            style: AppTextStyles.labelSmall,
          ),
          const SizedBox(height: 12),
          if (item.hasProofMetadata)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: PaymentProofImage(
                parentId: item.parentId,
                paymentId: item.paymentId,
                storagePath: item.proofStoragePath,
                onLoadedChanged: _onProofLoadedChanged,
              ),
            )
          else
            Text(
              'لا توجد صورة إيصال مرفقة',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          const SizedBox(height: 12),
          if (!busy && unresolved != null) ...[
            Container(
              key: const ValueKey('payment-review-unresolved'),
              padding: const EdgeInsets.all(AppSizes.paddingS),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'لم يتأكد حفظ القرار السابق: '
                    '${_describe(unresolved!, currency)}',
                    style: AppTextStyles.labelSmall,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: otherBusy || !_proofLoaded
                          ? null
                          : () => _retry(context, unresolved!),
                      child: const Text('إعادة المحاولة بنفس البيانات'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (otherBusy)
              Text(
                kPaymentReviewBusyMessage,
                textAlign: TextAlign.end,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (!_proofLoaded)
              Text(
                kPaymentProofNotLoadedMessage,
                key: const ValueKey('payment-review-proof-not-loaded'),
                textAlign: TextAlign.end,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton(
                  onPressed: otherBusy || !_proofLoaded
                      ? null
                      : () => _decide(context, PaymentReviewDecision.approve),
                  child: Text(PaymentReviewDecision.approve.label),
                ),
                OutlinedButton(
                  onPressed: otherBusy || !_proofLoaded
                      ? null
                      : () => _decide(context, PaymentReviewDecision.partial),
                  child: Text(PaymentReviewDecision.partial.label),
                ),
                TextButton(
                  onPressed: otherBusy || !_proofLoaded
                      ? null
                      : () => _decide(context, PaymentReviewDecision.reject),
                  child: Text(PaymentReviewDecision.reject.label),
                ),
              ],
            ),
          ],
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

typedef _DecisionDraft = ({
  String? notes,
  PaymentAmountMode? amountMode,
  int? amountMinorUnits,
});

class _DecisionDialogState extends State<_DecisionDialog> {
  final _notes = TextEditingController();
  final _draft = PaymentAmountDraft();
  String? _error;

  bool get _partial => widget.decision == PaymentReviewDecision.partial;

  @override
  void dispose() {
    _notes.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _confirm() {
    final snapshot = widget.item.amountSnapshot;
    final error = !isValidExpectedProofFileName(widget.item.proofFileName)
        ? 'لا يوجد إيصال صالح للمراجعة — أعد تحميل الصفحة'
        : _partial
        ? _draft.check(snapshot).error
        : snapshot.error;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final notes = _notes.text.trim();
    Navigator.pop<_DecisionDraft>(context, (
      notes: notes.isEmpty ? null : notes,
      amountMode: _partial ? _draft.mode : null,
      amountMinorUnits: _partial ? _draft.inputMinorUnits : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.item.currency;
    return AlertDialog(
      title: Text(widget.decision.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaymentReviewAmountPanel(
              snapshot: widget.item.amountSnapshot,
              decision: widget.decision.wire,
              draft: _draft,
              currency: currency,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: kPaymentReviewNotesMaxLength,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
          ],
        ),
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
