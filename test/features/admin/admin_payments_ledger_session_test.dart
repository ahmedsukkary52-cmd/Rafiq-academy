import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/admin_payments_ledger.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_payment_record.dart';
import 'package:rafiq_academy/features/admin/domain/entities/financial_summary_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_payment_ledger_labels.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_payments_ledger_session.dart';
import 'package:rafiq_academy/shared/widgets/app_status_chip.dart';

import '../../support/fake_callables.dart';

AdminPaymentRecord _record(String id, {String status = 'due'}) =>
    AdminPaymentRecord(
      id: id,
      studentId: 's-$id',
      studentName: 'الطالب $id',
      parentId: 'p-$id',
      parentName: 'ولي أمر $id',
      amount: 300,
      status: status,
      dueDate: DateTime(2026, 10, 1),
      method: 'vodafone_cash',
    );

class _FakeLedger extends AdminPaymentsLedger {
  _FakeLedger() : super(firestore: UnusedFirestore());

  final fetches = <({PaymentLedgerFilter filter, Object? cursor})>[];
  List<List<AdminPaymentRecord>> pages = [];
  FinancialSummaryEntity summaryValue = const FinancialSummaryEntity(
    totalRevenue: 100,
    totalPending: 50,
    totalOverdue: 10,
    paidCount: 1,
    dueCount: 1,
    overdueCount: 1,
    awaitingReviewCount: 0,
  );
  Object? summaryError;
  Object? pageError;

  @override
  Future<FinancialSummaryEntity> summary() async {
    if (summaryError != null) throw summaryError!;
    return summaryValue;
  }

  @override
  Future<AdminPaymentPage> fetchPage({
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
    Object? cursor,
    int limit = AdminPaymentsLedger.pageSize,
  }) async {
    if (pageError != null) throw pageError!;
    fetches.add((filter: filter, cursor: cursor));
    final index = cursor as int? ?? 0;
    return AdminPaymentPage(
      items: index < pages.length ? pages[index] : const [],
      cursor: index + 1 < pages.length ? index + 1 : null,
    );
  }
}

/// First fetch waits on [gate]; subsequent fetches return immediately.
class _GenerationLedger extends AdminPaymentsLedger {
  _GenerationLedger() : super(firestore: UnusedFirestore());

  final gate = Completer<void>();
  var fetchCount = 0;

  @override
  Future<FinancialSummaryEntity> summary() async =>
      const FinancialSummaryEntity(
        totalRevenue: 0,
        totalPending: 0,
        totalOverdue: 0,
        paidCount: 0,
        dueCount: 0,
        overdueCount: 0,
        awaitingReviewCount: 0,
      );

  @override
  Future<AdminPaymentPage> fetchPage({
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
    Object? cursor,
    int limit = AdminPaymentsLedger.pageSize,
  }) async {
    final n = ++fetchCount;
    if (n == 1) await gate.future;
    return AdminPaymentPage(
      items: [_record(n == 1 ? 'first' : 'second')],
      cursor: null,
    );
  }
}

void main() {
  group('adminPaymentLedgerLabels', () {
    test('formats dates and status chips', () {
      expect(adminPaymentLedgerDate(null), '—');
      expect(adminPaymentLedgerDate(DateTime(2026, 3, 5)), '5/3/2026');
      expect(
        adminPaymentLedgerTone(_record('1', status: 'overdue')),
        AppStatusTone.error,
      );
      expect(
        adminPaymentLedgerChipLabel(_record('1', status: 'overdue')),
        isNot(contains('overdue')),
      );

      final awaiting = AdminPaymentRecord(
        id: '2',
        studentId: 's',
        studentName: 'ط',
        parentId: 'p',
        parentName: 'و',
        amount: 1,
        status: 'due',
        reviewStatus: 'pending_review',
        dueDate: DateTime(2026, 1, 1),
        method: 'cash',
      );
      expect(adminPaymentLedgerTone(awaiting), AppStatusTone.info);
      expect(adminPaymentLedgerChipLabel(awaiting), 'بانتظار المراجعة');
    });
  });

  group('AdminPaymentsLedgerSession', () {
    test('reload loads summary and first page', () async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('a'), _record('b')],
        ];
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      await session.reload();
      await Future<void>.delayed(Duration.zero);

      expect(session.items.map((e) => e.id), ['a', 'b']);
      expect(session.summary?.totalRevenue, 100);
      expect(session.hasMore, isFalse);
      expect(session.loading, isFalse);
      expect(session.error, isNull);
      expect(ledger.fetches.single.cursor, isNull);
    });

    test('loadMore appends using the cursor', () async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('a')],
          [_record('b')],
        ];
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      await session.reload();
      await session.loadMore();

      expect(session.items.map((e) => e.id), ['a', 'b']);
      expect(ledger.fetches.map((f) => f.cursor), [null, 1]);
      expect(session.hasMore, isFalse);
    });

    test('setFilter resets and re-queries with the new filter', () async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('x', status: 'overdue')],
        ];
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      await session.reload();
      await session.setFilter(PaymentLedgerFilter.overdue);

      expect(session.filter, PaymentLedgerFilter.overdue);
      expect(ledger.fetches.last.filter, PaymentLedgerFilter.overdue);
      expect(ledger.fetches.last.cursor, isNull);
      expect(session.items, isNotEmpty);
    });

    test('page failure on loadMore keeps prior items and sets error', () async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('a')],
          [_record('b')],
        ];
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      await session.reload();
      ledger.pageError = const ServerException('network down');
      await session.loadMore();

      expect(session.items.map((e) => e.id), ['a']);
      expect(session.error, isNotNull);
      expect(session.loading, isFalse);
    });

    test('summary failure leaves the list usable and summary null', () async {
      final ledger = _FakeLedger()
        ..summaryError = StateError('agg failed')
        ..pages = [
          [_record('a')],
        ];
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      await session.reload();
      await Future<void>.delayed(Duration.zero);

      expect(session.summary, isNull);
      expect(session.items, isNotEmpty);
      expect(session.error, isNull);
    });

    test('stale in-flight fetch after reload is ignored', () async {
      final ledger = _GenerationLedger();
      final session = AdminPaymentsLedgerSession(ledger);
      addTearDown(session.dispose);

      final first = session.reload();
      await Future<void>.delayed(Duration.zero);
      final second = session.reload();
      ledger.gate.complete();
      await first;
      await second;

      expect(session.items.map((e) => e.id), ['second']);
      expect(ledger.fetchCount, greaterThanOrEqualTo(2));
    });
  });
}
