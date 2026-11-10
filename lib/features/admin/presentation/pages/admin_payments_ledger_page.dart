import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/user_facing_error.dart';
import '../../../../shared/presentation/academy_currency_label.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../parent/presentation/widgets/payment_proof_image.dart';
import '../../data/admin_payments_ledger.dart';
import '../../domain/entities/admin_payment_record.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../admin_format.dart';
import '../widgets/admin_figma_widgets.dart';

AdminPaymentsLedger defaultAdminPaymentsLedger() =>
    AdminPaymentsLedger(firestore: sl<FirebaseFirestore>());

String _date(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';

AppStatusTone _tone(AdminPaymentRecord p) {
  if (p.awaitingReview) return AppStatusTone.info;
  return switch (p.status) {
    'paid' => AppStatusTone.success,
    'overdue' => AppStatusTone.error,
    _ => AppStatusTone.warning,
  };
}

String _chipLabel(AdminPaymentRecord p) =>
    p.awaitingReview ? 'بانتظار المراجعة' : paymentStatusLabel(p.status);

/// One finance screen: live totals (server aggregates), status filters and a
/// cursor-paginated ledger; each row opens the full payment record.
class AdminPaymentsLedgerPage extends StatefulWidget {
  const AdminPaymentsLedgerPage({super.key, this.ledger});

  final AdminPaymentsLedger? ledger;

  @override
  State<AdminPaymentsLedgerPage> createState() =>
      _AdminPaymentsLedgerPageState();
}

class _AdminPaymentsLedgerPageState extends State<AdminPaymentsLedgerPage> {
  late final AdminPaymentsLedger _ledger =
      widget.ledger ?? defaultAdminPaymentsLedger();
  final _scroll = ScrollController();
  final List<AdminPaymentRecord> _items = [];
  PaymentLedgerFilter _filter = PaymentLedgerFilter.all;
  FinancialSummaryEntity? _summary;
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _loadSummary();
    await _loadMore();
  }

  Future<void> _loadSummary() async {
    try {
      final s = await _ledger.summary();
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      // The list still works; the totals strip stays hidden.
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await _ledger.fetchPage(filter: _filter, cursor: _cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.cursor != null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = userFacingErrorText(e.toString());
        _loading = false;
      });
    }
  }

  void _setFilter(PaymentLedgerFilter f) {
    if (_filter == f) return;
    _filter = f;
    _reload();
  }

  Future<void> _open(AdminPaymentRecord p) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPaymentDetailsPage(
          paymentId: p.id,
          initial: p,
          ledger: _ledger,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSubpageScaffold(
      title: 'سجل المدفوعات',
      body: Column(
        children: [
          if (_summary != null) _SummaryStrip(summary: _summary!),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final f in PaymentLedgerFilter.values)
                  AdminFilterChip(
                    key: Key('payments-filter-${f.name}'),
                    label: f.label,
                    selected: _filter == f,
                    onTap: () => _setFilter(f),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const AppLoadingWidget();
    if (_items.isEmpty && _error != null) {
      return AppErrorWidget(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'لا توجد مدفوعات',
        message: _filter == PaymentLedgerFilter.all
            ? 'ستظهر هنا فواتير أولياء الأمور فور إصدارها.'
            : 'لا توجد مدفوعات ضمن «${_filter.label}».',
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            if (_error != null) {
              return TextButton(
                onPressed: _loadMore,
                child: const Text('تعذر تحميل المزيد — إعادة المحاولة'),
              );
            }
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final p = _items[i];
          return _PaymentCard(
            key: Key('payment-${p.id}'),
            payment: p,
            onTap: () => _open(p),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final FinancialSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        child: Row(
          children: [
            cell(
              'محصّل',
              academyMoneyText(formatAdminCount(summary.totalRevenue.round())),
              AppColors.success,
            ),
            cell(
              'مستحق',
              academyMoneyText(formatAdminCount(summary.totalPending.round())),
              AppColors.warning,
            ),
            cell(
              'متأخر',
              academyMoneyText(formatAdminCount(summary.totalOverdue.round())),
              AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({super.key, required this.payment, required this.onTap});

  final AdminPaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.studentName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppStatusChip(label: _chipLabel(p), tone: _tone(p)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ولي الأمر: ${p.parentName}',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                academyMoneyLabel(p.amount),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                p.status == 'paid'
                    ? 'دُفعت ${_date(p.paidAt)}'
                    : 'تستحق ${_date(p.dueDate)}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full payment record: parties, amounts, method, proof (loaded through
/// Storage rules, never a public URL), reviewing supervisor and history.
class AdminPaymentDetailsPage extends StatefulWidget {
  const AdminPaymentDetailsPage({
    super.key,
    required this.paymentId,
    required this.ledger,
    this.initial,
  });

  final String paymentId;
  final AdminPaymentsLedger ledger;
  final AdminPaymentRecord? initial;

  @override
  State<AdminPaymentDetailsPage> createState() =>
      _AdminPaymentDetailsPageState();
}

class _AdminPaymentDetailsPageState extends State<AdminPaymentDetailsPage> {
  AdminPaymentRecord? _record;
  List<PaymentHistoryEntry>? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _record = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait<Object>([
        widget.ledger.record(widget.paymentId),
        widget.ledger.history(widget.paymentId),
      ]);
      if (!mounted) return;
      setState(() {
        _record = results[0] as AdminPaymentRecord;
        _history = results[1] as List<PaymentHistoryEntry>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingErrorText(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _record;
    return AppSubpageScaffold(
      title: 'تفاصيل الدفعة',
      body: p == null
          ? (_error == null
                ? const AppLoadingWidget()
                : AppErrorWidget(message: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                academyMoneyLabel(p.amount),
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            AppStatusChip(label: _chipLabel(p), tone: _tone(p)),
                          ],
                        ),
                        const Divider(height: 24),
                        _Row('الطالب', p.studentName),
                        _Row('ولي الأمر', p.parentName),
                        if (p.periodKey != null) _Row('الفترة', p.periodKey!),
                        _Row('تاريخ الاستحقاق', _date(p.dueDate)),
                        if (p.paidAt != null)
                          _Row('تاريخ السداد', _date(p.paidAt)),
                        _Row('طريقة الدفع', paymentMethodLabel(p.method)),
                        if (p.amountPaidConfirmed != null)
                          _Row(
                            'المبلغ المؤكد',
                            academyMoneyLabel(p.amountPaidConfirmed!),
                          ),
                        if (p.remainingAmount != null && p.status != 'paid')
                          _Row(
                            'المتبقي',
                            academyMoneyLabel(p.remainingAmount!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('الإيصال والمراجعة', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        _Row('حالة الإيصال', paymentReviewStatusLabel(p.reviewStatus)),
                        if (p.proofSubmittedAt != null)
                          _Row('تاريخ الرفع', _date(p.proofSubmittedAt)),
                        if (p.reviewedByName != null)
                          _Row('المراجِع', p.reviewedByName!),
                        if (p.reviewedAt != null)
                          _Row('تاريخ المراجعة', _date(p.reviewedAt)),
                        if (p.reviewNotes != null)
                          _Row('ملاحظات', p.reviewNotes!),
                        if (p.hasProof) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PaymentProofImage(
                              parentId: p.parentId,
                              paymentId: p.id,
                              storagePath: p.proofStoragePath,
                              height: 220,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('سجل المراجعات', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        if (_history == null)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_history!.isEmpty)
                          Text(
                            'لا توجد مراجعات مسجّلة لهذه الدفعة بعد.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          for (final h in _history!)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.history_rounded,
                                color: AppColors.primary,
                              ),
                              title: Text('${h.decisionLabel} — ${h.actorName}'),
                              subtitle: Text(
                                [
                                  _date(h.at),
                                  if (h.receiptAmount != null)
                                    'المستلم ${academyMoneyLabel(h.receiptAmount!)}',
                                  if (h.remainingAmount != null &&
                                      h.remainingAmount! > 0)
                                    'المتبقي ${academyMoneyLabel(h.remainingAmount!)}',
                                ].join(' · '),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
