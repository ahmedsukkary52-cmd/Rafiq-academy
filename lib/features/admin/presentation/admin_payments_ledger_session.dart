import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/error/user_facing_error.dart';
import '../data/admin_payments_ledger.dart';
import '../domain/entities/admin_payment_record.dart';
import '../domain/entities/financial_summary_entity.dart';

/// Owns ledger list/filter/pagination state for [AdminPaymentsLedgerPage].
///
/// Keeps Firestore I/O behind [AdminPaymentsLedger] and isolates the
/// generation-guarded load machine so it can be unit-tested without widgets.
class AdminPaymentsLedgerSession extends ChangeNotifier {
  AdminPaymentsLedgerSession(this._ledger);

  final AdminPaymentsLedger _ledger;

  final List<AdminPaymentRecord> items = [];
  PaymentLedgerFilter filter = PaymentLedgerFilter.all;
  FinancialSummaryEntity? summary;
  Object? cursor;
  bool hasMore = true;
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> reload() async {
    _generation++;
    items.clear();
    cursor = null;
    hasMore = true;
    error = null;
    loading = false;
    _notify();
    // Fire-and-forget totals; list remains usable if aggregates fail.
    unawaited(_loadSummary());
    await loadMore();
  }

  Future<void> setFilter(PaymentLedgerFilter next) async {
    if (filter == next) return;
    filter = next;
    await reload();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    loading = true;
    _notify();
    try {
      final page = await _ledger.fetchPage(filter: filter, cursor: cursor);
      if (_disposed || generation != _generation) return;
      items.addAll(page.items);
      cursor = page.cursor;
      hasMore = page.cursor != null;
      loading = false;
      _notify();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = userFacingErrorText(e.toString());
      loading = false;
      _notify();
    }
  }

  Future<void> _loadSummary() async {
    try {
      final value = await _ledger.summary();
      if (_disposed) return;
      summary = value;
      _notify();
    } catch (_) {
      // Product behavior: hide the totals strip; the paginated list still works.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
