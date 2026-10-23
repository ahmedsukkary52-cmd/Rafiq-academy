import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';
import 'package:rafiq_academy/shared/widgets/payment_review_amount_panel.dart';

const _snapshot = PaymentAmountSnapshot(invoice: 20000, previous: 6000);

Future<PaymentAmountDraft> _pump(
  WidgetTester tester, {
  String decision = PaymentReviewWire.partial,
  PaymentAmountSnapshot snapshot = _snapshot,
}) async {
  final draft = PaymentAmountDraft();
  addTearDown(draft.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PaymentReviewAmountPanel(
            snapshot: snapshot,
            decision: decision,
            draft: draft,
          ),
        ),
      ),
    ),
  );
  return draft;
}

Finder _row(String label, String value) => find.byWidgetPredicate(
  (w) =>
      w is Row &&
      w.children.length == 2 &&
      w.children.first is Expanded &&
      ((w.children.first as Expanded).child as Text).data == label &&
      (w.children.last as Text).data == value,
);

void main() {
  testWidgets(
    'shows invoice, previous total and remaining; receipt is default',
    (tester) async {
      final draft = await _pump(tester);
      expect(_row('قيمة الفاتورة', '200'), findsOneWidget);
      expect(_row('المؤكد سابقاً', '60'), findsOneWidget);
      expect(_row('المتبقي', '140'), findsOneWidget);
      expect(draft.mode, PaymentAmountMode.receipt);
      expect(find.text('قيمة هذا الإيصال'), findsOneWidget);
      expect(
        find.text('أدخل المبلغ لعرض الإجمالي الجديد والمتبقي'),
        findsOneWidget,
      );
    },
  );

  testWidgets('receipt summary previews the new total and remaining', (
    tester,
  ) async {
    final draft = await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-input')),
      '50.5',
    );
    await tester.pump();
    expect(_row('قيمة هذا الإيصال', '50.50'), findsOneWidget);
    expect(_row('الإجمالي المؤكد الجديد', '110.50'), findsOneWidget);
    expect(_row('المتبقي المتوقع', '89.50'), findsOneWidget);
    expect(draft.inputMinorUnits, 5050);
  });

  testWidgets('cumulative mode clears the value and reads it as the total', (
    tester,
  ) async {
    final draft = await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-input')),
      '50',
    );
    await tester.tap(
      find.byKey(const ValueKey('payment-amount-mode-cumulative')),
    );
    await tester.pump();
    expect(draft.mode, PaymentAmountMode.cumulative);
    expect(draft.input.text, isEmpty);
    expect(find.text('الإجمالي المؤكد بعد هذا الإيصال'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-input')),
      '150',
    );
    await tester.pump();
    expect(_row('قيمة هذا الإيصال', '90'), findsOneWidget);
    expect(_row('المتبقي المتوقع', '50'), findsOneWidget);
  });

  testWidgets('an amount covering the invoice shows the full-approval hint', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-input')),
      '140',
    );
    await tester.pump();
    expect(find.textContaining('استخدم الاعتماد الكامل'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('payment-amount-input')),
      '1.234',
    );
    await tester.pump();
    expect(find.textContaining('منزلتين عشريتين'), findsWidgets);
  });

  testWidgets('approval previews the full invoice; no amount field', (
    tester,
  ) async {
    await _pump(tester, decision: PaymentReviewWire.approve);
    expect(find.byKey(const ValueKey('payment-amount-input')), findsNothing);
    expect(_row('يغطي هذا الإيصال', '140'), findsOneWidget);
    expect(_row('الإجمالي المؤكد الجديد', '200'), findsOneWidget);
    expect(_row('المتبقي المتوقع', '0'), findsOneWidget);
  });

  testWidgets('rejection states the totals do not change', (tester) async {
    await _pump(tester, decision: PaymentReviewWire.reject);
    expect(find.byKey(const ValueKey('payment-amount-input')), findsNothing);
    expect(find.text('الرفض لا يغيّر المبالغ المؤكدة'), findsOneWidget);
  });

  testWidgets('a corrupt stored total blocks the decision section', (
    tester,
  ) async {
    await _pump(
      tester,
      snapshot: const PaymentAmountSnapshot(invoice: 20000, previous: 20000),
    );
    expect(
      find.text('المبلغ المؤكد السابق لهذه الدفعة غير صالح'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('payment-amount-input')), findsNothing);
  });
}
