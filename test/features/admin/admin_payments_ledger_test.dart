import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/data/admin_payments_ledger.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_payment_record.dart';
import 'package:rafiq_academy/features/admin/domain/entities/financial_summary_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_payments_ledger_page.dart';

import '../../support/fake_callables.dart';

AdminPaymentRecord _record(
  String id, {
  String status = 'due',
  String? reviewStatus,
  double amount = 300,
}) => AdminPaymentRecord(
  id: id,
  studentId: 's-$id',
  studentName: 'الطالب $id',
  parentId: 'p-$id',
  parentName: 'ولي أمر $id',
  amount: amount,
  status: status,
  reviewStatus: reviewStatus,
  dueDate: DateTime(2026, 10, 1),
  method: 'vodafone_cash',
);

class _FakeLedger extends AdminPaymentsLedger {
  _FakeLedger() : super(firestore: UnusedFirestore());

  final fetches = <({PaymentLedgerFilter filter, Object? cursor})>[];
  List<List<AdminPaymentRecord>> pages = [];
  FinancialSummaryEntity summaryValue = const FinancialSummaryEntity(
    totalRevenue: 1500,
    totalPending: 600,
    totalOverdue: 300,
    paidCount: 5,
    dueCount: 2,
    overdueCount: 1,
    awaitingReviewCount: 1,
  );
  AdminPaymentRecord? detail;
  List<PaymentHistoryEntry> historyValue = const [];

  @override
  Future<FinancialSummaryEntity> summary() async => summaryValue;

  @override
  Future<AdminPaymentPage> fetchPage({
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
    Object? cursor,
    int limit = AdminPaymentsLedger.pageSize,
  }) async {
    fetches.add((filter: filter, cursor: cursor));
    final index = cursor as int? ?? 0;
    return AdminPaymentPage(
      items: index < pages.length ? pages[index] : const [],
      cursor: index + 1 < pages.length ? index + 1 : null,
    );
  }

  @override
  Future<AdminPaymentRecord> record(String paymentId) async =>
      detail ?? _record(paymentId);

  @override
  Future<List<PaymentHistoryEntry>> history(String paymentId) async =>
      historyValue;
}

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  group('summaryFromTotals', () {
    test('revenue counts paid invoices plus confirmed partials', () {
      final s = summaryFromTotals(
        paid: const StatusTotals(count: 2, amount: 600, confirmed: 600),
        due: const StatusTotals(count: 3, amount: 900, confirmed: 100),
        overdue: const StatusTotals(count: 1, amount: 300, confirmed: 50),
        awaitingReviewCount: 4,
      );
      expect(s.totalRevenue, 750);
      expect(s.totalPending, 800);
      expect(s.totalOverdue, 250);
      expect(s.paidCount, 2);
      expect(s.unpaidCount, 4);
      expect(s.awaitingReviewCount, 4);
    });

    test('outstanding never goes negative', () {
      final s = summaryFromTotals(
        paid: const StatusTotals(count: 0, amount: 0, confirmed: 0),
        due: const StatusTotals(count: 1, amount: 100, confirmed: 150),
        overdue: const StatusTotals(count: 0, amount: 0, confirmed: 0),
        awaitingReviewCount: 0,
      );
      expect(s.totalPending, 0);
    });
  });

  group('paymentRecordFromMap', () {
    test('maps the full record and resolves names, never ids', () {
      final r = paymentRecordFromMap('pay1', {
        'studentId': 's1',
        'parentId': 'p1',
        'amount': 450,
        'status': 'due',
        'reviewStatus': 'partial',
        'dueDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'method': 'vodafone_cash',
        'amountPaidConfirmed': 200,
        'remainingAmount': 250,
        'proofStoragePath': 'payment_proofs/p1/pay1/a.jpg',
        'reviewedBy': 'sup1',
        'reviewNotes': 'تم استلام جزء',
      }, {'s1': 'أحمد', 'p1': 'محمد', 'sup1': 'المشرف خالد'});
      expect(r.studentName, 'أحمد');
      expect(r.parentName, 'محمد');
      expect(r.reviewedByName, 'المشرف خالد');
      expect(r.amount, 450);
      expect(r.amountPaidConfirmed, 200);
      expect(r.remainingAmount, 250);
      expect(r.hasProof, isTrue);
      expect(r.dueDate, DateTime(2026, 11, 1));
      expect(paymentMethodLabel(r.method), 'فودافون كاش');
      expect(paymentReviewStatusLabel(r.reviewStatus), 'اعتماد جزئي');
    });

    test('unknown people get role labels instead of raw ids', () {
      final r = paymentRecordFromMap('pay2', {
        'studentId': 'sX',
        'parentId': 'pX',
        'amount': 100,
        'reviewedBy': 'uX',
      }, const {});
      expect(r.studentName, 'طالب');
      expect(r.parentName, 'ولي أمر');
      expect(r.reviewedByName, 'مشرف');
      expect(r.status, 'due');
      expect(r.hasProof, isFalse);
    });
  });

  test('paymentHistoryFromMap reads the review audit entry', () {
    final h = paymentHistoryFromMap({
      'actorId': 'sup1',
      'timestamp': Timestamp.fromDate(DateTime(2026, 10, 20)),
      'metadata': {
        'decision': 'partial',
        'newStatus': 'due',
        'receiptAmount': 200,
        'remainingAmount': 250,
      },
    }, {'sup1': 'خالد'});
    expect(h.actorName, 'خالد');
    expect(h.decisionLabel, 'اعتماد جزئي');
    expect(h.receiptAmount, 200);
    expect(h.remainingAmount, 250);
    expect(h.at, DateTime(2026, 10, 20));
  });

  group('AdminPaymentsLedgerPage', () {
    testWidgets('shows EGP totals, names and paginates', (tester) async {
      final ledger = _FakeLedger()
        ..pages = [
          [for (var i = 0; i < 20; i++) _record('a$i')],
          [_record('b0', status: 'paid')],
        ];
      await tester.pumpWidget(_host(AdminPaymentsLedgerPage(ledger: ledger)));
      await tester.pumpAndSettle();

      expect(find.text('1,500 جنيه'), findsOneWidget);
      expect(find.text('الطالب a0'), findsOneWidget);
      expect(find.text('ولي الأمر: ولي أمر a0'), findsOneWidget);
      expect(find.textContaining('s-a0'), findsNothing);
      expect(ledger.fetches.single.cursor, isNull);

      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(ledger.fetches.length, 2);
      expect(ledger.fetches.last.cursor, 1);
    });

    testWidgets('filters re-query the server with the lifecycle filter', (
      tester,
    ) async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('x', reviewStatus: 'pending_review')],
        ];
      await tester.pumpWidget(_host(AdminPaymentsLedgerPage(ledger: ledger)));
      await tester.pumpAndSettle();
      expect(find.text('بانتظار المراجعة'), findsWidgets);

      await tester.tap(find.byKey(const Key('payments-filter-overdue')));
      await tester.pumpAndSettle();
      expect(ledger.fetches.last.filter, PaymentLedgerFilter.overdue);
      expect(ledger.fetches.last.cursor, isNull);
    });

    testWidgets('empty state names the active filter', (tester) async {
      final ledger = _FakeLedger();
      await tester.pumpWidget(_host(AdminPaymentsLedgerPage(ledger: ledger)));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد مدفوعات'), findsOneWidget);
    });

    testWidgets('row opens the full record with reviewer and history', (
      tester,
    ) async {
      final ledger = _FakeLedger()
        ..pages = [
          [_record('d1', status: 'paid', reviewStatus: 'approved')],
        ]
        ..detail = AdminPaymentRecord(
          id: 'd1',
          studentId: 's1',
          studentName: 'أحمد',
          parentId: 'p1',
          parentName: 'محمد',
          amount: 300,
          status: 'paid',
          reviewStatus: 'approved',
          dueDate: DateTime(2026, 10, 1),
          paidAt: DateTime(2026, 10, 3),
          method: 'instapay',
          reviewedByName: 'المشرف خالد',
          reviewedAt: DateTime(2026, 10, 3),
        )
        ..historyValue = [
          PaymentHistoryEntry(
            at: DateTime(2026, 10, 3),
            actorName: 'المشرف خالد',
            decision: 'approve',
            newStatus: 'paid',
            receiptAmount: 300,
          ),
        ];
      await tester.pumpWidget(_host(AdminPaymentsLedgerPage(ledger: ledger)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payment-d1')));
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل الدفعة'), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('محمد'), findsOneWidget);
      expect(find.text('إنستاباي'), findsOneWidget);
      expect(find.text('المشرف خالد'), findsOneWidget);
      expect(find.text('تم اعتماد الإيصال'), findsOneWidget);
      expect(find.text('اعتماد كامل — المشرف خالد'), findsOneWidget);
    });
  });
}
