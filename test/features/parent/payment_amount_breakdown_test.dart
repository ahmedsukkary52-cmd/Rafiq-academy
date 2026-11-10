import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_display.dart';
import 'package:rafiq_academy/features/parent/presentation/widgets/payment_amount_breakdown.dart';

PaymentEntity _payment({
  PaymentStatus status = PaymentStatus.due,
  String? reviewStatus = 'partial',
  double? confirmed = 60,
  double amount = 200,
}) => PaymentEntity(
  id: 'p1',
  studentId: 's1',
  parentId: 'par1',
  amount: amount,
  dueDate: DateTime(2026, 10, 5),
  status: status,
  reviewStatus: reviewStatus,
  amountPaidConfirmed: confirmed,
  remainingAmount: confirmed == null ? null : amount - confirmed,
);

void main() {
  group('Parent amounts after partial reviews', () {
    test('outstanding is the invoice minus the cumulative confirmed total', () {
      final p = _payment();
      expect(p.hasPartialConfirmation, isTrue);
      expect(p.confirmedPartialAmount, 60);
      expect(p.outstandingAmount, 140);
    });

    test('kept across a new upload or a rejection of the next proof', () {
      for (final review in ['pending_review', 'rejected']) {
        final p = _payment(reviewStatus: review, confirmed: 110);
        expect(p.hasPartialConfirmation, isTrue, reason: review);
        expect(p.outstandingAmount, 90, reason: review);
      }
    });

    test('no confirmation means the full invoice is owed', () {
      final p = _payment(reviewStatus: null, confirmed: null);
      expect(p.hasPartialConfirmation, isFalse);
      expect(p.outstandingAmount, 200);
    });

    test(
      'paid invoices owe nothing; corrupt totals fall back to the invoice',
      () {
        final paid = _payment(status: PaymentStatus.paid, confirmed: 200);
        expect(paid.outstandingAmount, 0);
        expect(paid.hasPartialConfirmation, isFalse);
        final corrupt = _payment(confirmed: 250);
        expect(corrupt.hasPartialConfirmation, isFalse);
        expect(corrupt.outstandingAmount, 200);
      },
    );

    test('money labels keep piasters only when present', () {
      expect(parentMoneyLabel(200), '٢٠٠ جنيه');
      expect(parentMoneyLabel(66.67), '٦٦٫٦٧ جنيه');
    });
  });

  testWidgets('breakdown shows total, confirmed so far and still owed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentAmountBreakdown(payment: _payment(confirmed: 66.67)),
        ),
      ),
    );
    expect(find.text('إجمالي الفاتورة'), findsOneWidget);
    expect(find.text('٢٠٠ جنيه'), findsOneWidget);
    expect(find.text('المؤكد حتى الآن'), findsOneWidget);
    expect(find.text('٦٦٫٦٧ جنيه'), findsOneWidget);
    expect(find.text('المتبقي للدفع'), findsOneWidget);
    expect(find.text('١٣٣٫٣٣ جنيه'), findsOneWidget);
  });
}
