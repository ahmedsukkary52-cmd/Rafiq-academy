import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/payment_review_amount_panel.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../../parent/presentation/widgets/payment_proof_image.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/repositories/parent_repository.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

enum _PaymentFilter { all, awaiting, reviewed }

String _money(double v) => '${formatMoneyAmount(v)} ر.س';

/// Supervisor payment submissions — review external-pay proofs.
class SupervisorPaymentsPage extends StatefulWidget {
  const SupervisorPaymentsPage({super.key});

  @override
  State<SupervisorPaymentsPage> createState() => _SupervisorPaymentsPageState();
}

class _SupervisorPaymentsPageState extends State<SupervisorPaymentsPage> {
  _PaymentFilter _filter = _PaymentFilter.all;
  Map<String, String> _names = const {};
  String _loadedHalaqaKey = '';

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

  String _halaqaKey(SupervisorState state) {
    final ids = state.halaqat.map((h) => h.id).toList()..sort();
    return ids.join('|');
  }

  Future<void> _resolveNames(List<String> ids) async {
    if (ids.isEmpty) return;
    final result = await sl<SupervisorRepository>().getUserDisplayNames(ids);
    if (!mounted) return;
    result.fold((_) {}, (map) {
      setState(() => _names = {..._names, ...map});
    });
  }

  void _load({bool force = false}) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final bloc = context.read<SupervisorBloc>();
    final state = bloc.state;

    // Wait until supervised halaqat are loaded to avoid empty false-success.
    if (state.halaqatStatus != SectionStatus.loaded) {
      if (state.halaqatStatus == SectionStatus.initial ||
          state.halaqatStatus == SectionStatus.loading) {
        return;
      }
    }

    final key = _halaqaKey(state);
    if (!force &&
        key == _loadedHalaqaKey &&
        state.paymentsStatus == SectionStatus.loaded) {
      return;
    }
    _loadedHalaqaKey = key;

    final ids = _studentIds(state);
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
    return MultiBlocListener(
      listeners: [
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (p, c) =>
              p.halaqatStatus != c.halaqatStatus || p.halaqat != c.halaqat,
          listener: (context, state) => _load(),
        ),
        BlocListener<SupervisorBloc, SupervisorState>(
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
              AppSnackBar.showSuccess(
                context,
                state.reviewPaymentMessage ?? 'تم حفظ نتيجة المراجعة',
              );
              context.read<SupervisorBloc>().add(
                const ResetReviewPaymentEvent(),
              );
            } else if (state.reviewPaymentStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.reviewPaymentError ?? 'تعذر حفظ المراجعة',
              );
              context.read<SupervisorBloc>().add(
                const ResetReviewPaymentEvent(),
              );
            }
          },
        ),
      ],
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
              p.halaqat != c.halaqat ||
              p.halaqatStatus != c.halaqatStatus,
          builder: (context, state) {
            final waitingHalaqat =
                state.halaqatStatus == SectionStatus.initial ||
                state.halaqatStatus == SectionStatus.loading;
            if (waitingHalaqat ||
                state.paymentsStatus == SectionStatus.loading ||
                state.paymentsStatus == SectionStatus.initial) {
              return const SupervisorPaymentsListSkeleton();
            }
            if (state.halaqatStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.halaqatError ?? 'تعذر تحميل الحلقات',
                onRetry: () {
                  final auth = context.read<AuthBloc>().state;
                  if (auth is! AuthAuthenticated) return;
                  context.read<SupervisorBloc>().add(
                    LoadSupervisedHalaqatEvent(auth.user.uid),
                  );
                },
              );
            }
            if (state.paymentsStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.paymentsError ?? 'تعذر التحميل',
                onRetry: () => _load(force: true),
              );
            }

            final all = state.payments;
            final awaiting = all.where((p) => p.hasProofAwaitingReview).length;
            final reviewed = all.where((p) => p.hasSupervisorReview).length;
            final visible = _visible(all);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _load(force: true),
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

@visibleForTesting
Widget supervisorPaymentReviewPageForTest(PaymentEntity payment) =>
    _PaymentReviewPage(
      payment: payment,
      studentName: payment.studentId,
      parentName: payment.parentId,
    );

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
  final _draft = PaymentAmountDraft();
  PaymentReviewDecision _decision = PaymentReviewDecision.approved;

  /// Restored from an earlier submission whose outcome is unknown.
  bool _restored = false;

  /// Storage path whose image is currently displayed; null while loading or
  /// after a failure.
  String? _loadedProofPath;

  String get _proofPath => widget.payment.proofStoragePath?.trim() ?? '';

  /// A review requires the image of the current proof to be on screen.
  bool get _proofLoaded =>
      _proofPath.isNotEmpty && _loadedProofPath == _proofPath;

  void _onProofLoadedChanged(bool loaded) {
    setState(() => _loadedProofPath = loaded ? _proofPath : null);
  }

  @override
  void initState() {
    super.initState();
    // A pending proof starts a new review cycle; its kept reviewNotes belong
    // to the previous proof and must not be re-saved by default.
    final pending =
        widget.payment.reviewStatus?.trim() ==
        ParentPaymentProofContract.pendingReview;
    _notesCtrl.text = pending ? '' : widget.payment.reviewNotes ?? '';

    final unresolved = context
        .read<SupervisorBloc>()
        .state
        .reviewPaymentUnresolved[widget.payment.id];
    if (_reviewable &&
        unresolved != null &&
        unresolved.targetsProof(
          fileName: widget.payment.proofFileName,
          proofCycleId: widget.payment.proofCycleId,
        )) {
      _restore(unresolved);
    }
  }

  /// Same content ⇒ the bloc re-sends it with the same requestId.
  void _restore(PaymentReviewCommand command) {
    _restored = true;
    _decision = PaymentReviewDecision.values.firstWhere(
      (d) => d.wire == command.decision,
    );
    _notesCtrl.text = command.notes;
    final mode = command.amountMode;
    final amount = command.amountMinorUnits;
    if (mode != null) _draft.mode = mode;
    if (amount != null) _draft.input.text = formatMinorUnits(amount);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _draft.dispose();
    super.dispose();
  }

  PaymentAmountSnapshot get _snapshot => PaymentAmountSnapshot.fromAmounts(
    invoiceAmount: widget.payment.amount,
    amountPaidConfirmed: widget.payment.amountPaidConfirmed,
  );

  /// Only a pending proof with its file name can be reviewed (proof-bound).
  bool get _reviewable {
    final p = widget.payment;
    return p.status != PaymentStatus.paid &&
        p.reviewStatus?.trim() == ParentPaymentProofContract.pendingReview &&
        isValidExpectedProofFileName(p.proofFileName);
  }

  void _submit() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || !_reviewable || !_proofLoaded) return;
    final bloc = context.read<SupervisorBloc>();
    if (bloc.state.reviewPaymentStatus == SubmissionStatus.submitting) {
      AppSnackBar.showInfo(context, kPaymentReviewBusyMessage);
      return;
    }

    final partial = _decision == PaymentReviewDecision.partial;
    final snapshot = _snapshot;
    final error = partial ? _draft.check(snapshot).error : snapshot.error;
    if (error != null) {
      AppSnackBar.showInfo(context, error);
      return;
    }

    bloc.add(
      ReviewPaymentProofEvent(
        supervisorId: auth.user.uid,
        snapshot: snapshot,
        command: PaymentReviewCommand(
          paymentId: widget.payment.id,
          decision: _decision.wire,
          notes: _notesCtrl.text,
          amountMode: partial ? _draft.mode : null,
          amountMinorUnits: partial ? _draft.inputMinorUnits : null,
          expectedProofFileName: widget.payment.proofFileName ?? '',
          expectedProofCycleId: widget.payment.proofCycleId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final proofPath = _proofPath;
    final reviewable = _reviewable;
    final proofLoaded = _proofLoaded;

    return BlocListener<SupervisorBloc, SupervisorState>(
      // Only outcomes of this payment's review concern this screen.
      listenWhen: (a, b) =>
          b.reviewPaymentId == p.id &&
          a.reviewStatusFor(p.id) != b.reviewStatusFor(p.id),
      listener: (context, state) {
        final error = state.reviewPaymentError;
        // Reviewed, or this screen's proof is stale: the list reloads behind.
        if (state.reviewPaymentStatus == SubmissionStatus.success ||
            (state.reviewPaymentStatus == SubmissionStatus.error &&
                (isPaymentProofChangedMessage(error) ||
                    error == kPaymentNoLongerPendingNotice))) {
          Navigator.of(context).maybePop();
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'مراجعة إثبات الدفع',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (a, b) =>
              a.reviewPaymentStatus != b.reviewPaymentStatus ||
              a.reviewPaymentId != b.reviewPaymentId,
          builder: (context, state) {
            final submitting =
                state.reviewPaymentStatus == SubmissionStatus.submitting;
            final busy = submitting && state.reviewPaymentId == p.id;
            final otherBusy = submitting && state.reviewPaymentId != p.id;
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
                        value: _money(p.amount),
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
                if (proofPath.isEmpty)
                  const AppCard(child: Text('لا توجد صورة إثبات مرفقة'))
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PaymentProofImage(
                      parentId: p.parentId,
                      paymentId: p.id,
                      storagePath: proofPath,
                      height: 360,
                      onLoadedChanged: _onProofLoadedChanged,
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
                if (!reviewable)
                  AppCard(
                    child: Text(
                      'لا يوجد إيصال بانتظار المراجعة لهذه الدفعة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else ...[
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
                  AppCard(
                    child: PaymentReviewAmountPanel(
                      snapshot: _snapshot,
                      decision: _decision.wire,
                      draft: _draft,
                      currency: 'ر.س',
                      enabled: !busy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    enabled: !busy,
                    maxLines: 3,
                    maxLength: kPaymentReviewNotesMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات المراجعة',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_restored && !busy) ...[
                    const SizedBox(height: 8),
                    Text(
                      'لم يتأكد حفظ المراجعة السابقة لهذه الدفعة — البيانات '
                      'المعروضة هي نفس الطلب السابق، أعد الإرسال دون تعديلها '
                      'لاسترداد نتيجته.',
                      key: const ValueKey('payment-review-restored'),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                  if (otherBusy) ...[
                    const SizedBox(height: 8),
                    Text(
                      kPaymentReviewBusyMessage,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (!proofLoaded) ...[
                    const SizedBox(height: 8),
                    Text(
                      kPaymentProofNotLoadedMessage,
                      key: const ValueKey('payment-review-proof-not-loaded'),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy || otherBusy || !proofLoaded
                        ? null
                        : _submit,
                    child: Text(busy ? 'جاري الحفظ…' : 'حفظ نتيجة المراجعة'),
                  ),
                ],
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

  String _reportReviewLabel(PaymentEntity p) {
    return switch (p.reviewStatus) {
      ParentPaymentProofContract.approved => 'مقبول',
      ParentPaymentProofContract.rejected => 'مرفوض',
      ParentPaymentProofContract.partial => 'جزئي',
      ParentPaymentProofContract.pendingReview => 'بانتظار المراجعة',
      _ => 'مُراجعة',
    };
  }

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
                        '${_reportReviewLabel(p)} · ${(p.amountPaidConfirmed ?? p.amount).toStringAsFixed(0)} ر.س',
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
