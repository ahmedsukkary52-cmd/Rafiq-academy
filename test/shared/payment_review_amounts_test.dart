import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/data/payment_review_callable.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';

PaymentReviewPreview _partial(
  PaymentAmountSnapshot snapshot,
  PaymentAmountMode mode,
  int input,
) {
  final check = previewPartialPayment(
    snapshot: snapshot,
    mode: mode,
    input: input,
  );
  expect(check.error, isNull);
  return check.preview!;
}

String? _partialError(
  PaymentAmountSnapshot snapshot,
  PaymentAmountMode mode,
  int? input,
) => previewPartialPayment(snapshot: snapshot, mode: mode, input: input).error;

PaymentReviewCommand _command({
  String paymentId = 'p1',
  String decision = PaymentReviewWire.partial,
  String? notes,
  PaymentAmountMode? mode = PaymentAmountMode.receipt,
  int? amount = 6000,
  String proof = '1790000000000.jpg',
  String? cycle,
}) => PaymentReviewCommand(
  paymentId: paymentId,
  decision: decision,
  notes: notes,
  amountMode: mode,
  amountMinorUnits: amount,
  expectedProofFileName: proof,
  expectedProofCycleId: cycle,
);

const _cycleA = 'pc_AAAAAAAAAAAAAAAAAAAAAAAA';
const _cycleB = 'pc_BBBBBBBBBBBBBBBBBBBBBBBB';

void main() {
  group('money in minor units', () {
    test('moneyToMinorUnits mirrors the server toMinorUnits', () {
      expect(moneyToMinorUnits(200), 20000);
      expect(moneyToMinorUnits(33.33), 3333);
      expect(moneyToMinorUnits(0.1 + 0.2), 30);
      expect(moneyToMinorUnits(0), 0);
      expect(moneyToMinorUnits(1.005), isNull);
      expect(moneyToMinorUnits(double.nan), isNull);
      expect(moneyToMinorUnits(double.infinity), isNull);
      expect(moneyToMinorUnits(null), isNull);
    });

    test('parseMoneyInput is exact and accepts Arabic digits', () {
      expect(parseMoneyInput('60'), 6000);
      expect(parseMoneyInput(' 33.3 '), 3330);
      expect(parseMoneyInput('33.33'), 3333);
      expect(parseMoneyInput('٦٠٫٥'), 6050);
      expect(parseMoneyInput('۱۲'), 1200);
      for (final bad in ['', '-5', '1.005', 'abc', '1,5', '.5', '5.', '1e3']) {
        expect(parseMoneyInput(bad), isNull, reason: bad);
      }
    });

    test('formatting keeps whole amounts whole', () {
      expect(formatMinorUnits(6000), '60');
      expect(formatMinorUnits(3350), '33.50');
      expect(formatMinorUnits(5), '0.05');
      expect(formatMoneyAmount(140), '140');
      expect(formatMoneyAmount(66.67), '66.67');
    });
  });

  group('snapshot', () {
    test('reads invoice and previous confirmed total', () {
      final s = PaymentAmountSnapshot.fromAmounts(
        invoiceAmount: 200,
        amountPaidConfirmed: 60,
      );
      expect(s.invoice, 20000);
      expect(s.previous, 6000);
      expect(s.remaining, 14000);
      expect(s.isValid, isTrue);
      expect(PaymentAmountSnapshot.fromAmounts(invoiceAmount: 200).previous, 0);
    });

    test('corrupt stored values fail closed', () {
      for (final s in [
        PaymentAmountSnapshot.fromAmounts(invoiceAmount: 0),
        PaymentAmountSnapshot.fromAmounts(invoiceAmount: 10.001),
        PaymentAmountSnapshot.fromAmounts(
          invoiceAmount: 200,
          amountPaidConfirmed: 200,
        ),
        PaymentAmountSnapshot.fromAmounts(
          invoiceAmount: 200,
          amountPaidConfirmed: -1,
        ),
        PaymentAmountSnapshot.fromAmounts(
          invoiceAmount: 200,
          amountPaidConfirmed: 1.001,
        ),
      ]) {
        expect(s.isValid, isFalse, reason: '$s');
        expect(s.remaining, 0);
        expect(
          _partialError(s, PaymentAmountMode.receipt, 100),
          isNotNull,
          reason: '$s',
        );
      }
    });
  });

  group('partial previews (server parity)', () {
    const invoice = PaymentAmountSnapshot(invoice: 20000);

    test('receipt: first then second receipt add to the total', () {
      final first = _partial(invoice, PaymentAmountMode.receipt, 6000);
      expect(
        first,
        const PaymentReviewPreview(
          receipt: 6000,
          total: 6000,
          remaining: 14000,
        ),
      );
      final afterFirst = PaymentAmountSnapshot(
        invoice: 20000,
        previous: first.total,
      );
      final second = _partial(afterFirst, PaymentAmountMode.receipt, 5000);
      expect(
        second,
        const PaymentReviewPreview(
          receipt: 5000,
          total: 11000,
          remaining: 9000,
        ),
      );
    });

    test('cumulative: the entered value is the new total', () {
      const s = PaymentAmountSnapshot(invoice: 20000, previous: 6000);
      expect(
        _partial(s, PaymentAmountMode.cumulative, 15000),
        const PaymentReviewPreview(
          receipt: 9000,
          total: 15000,
          remaining: 5000,
        ),
      );
    });

    test('cumulative total cannot shrink or repeat', () {
      const s = PaymentAmountSnapshot(invoice: 20000, previous: 6000);
      expect(
        _partialError(s, PaymentAmountMode.cumulative, 6000),
        contains('60'),
      );
      expect(_partialError(s, PaymentAmountMode.cumulative, 5000), isNotNull);
    });

    test('reaching or exceeding the invoice is refused', () {
      const s = PaymentAmountSnapshot(invoice: 20000, previous: 6000);
      expect(
        _partialError(s, PaymentAmountMode.receipt, 14000),
        contains('الاعتماد الكامل'),
      );
      expect(
        _partialError(s, PaymentAmountMode.receipt, 14001),
        contains('140'),
      );
      expect(
        _partialError(s, PaymentAmountMode.cumulative, 20000),
        contains('الاعتماد الكامل'),
      );
      expect(_partialError(s, PaymentAmountMode.cumulative, 20001), isNotNull);
    });

    test('zero, negative and missing values are refused', () {
      for (final v in [0, -100, null]) {
        expect(
          _partialError(invoice, PaymentAmountMode.receipt, v),
          isNotNull,
          reason: '$v',
        );
      }
    });

    test('no floating drift across receipts and approval', () {
      const s = PaymentAmountSnapshot(invoice: 10000);
      final a = _partial(
        s,
        PaymentAmountMode.receipt,
        parseMoneyInput('33.33')!,
      );
      final b = _partial(
        PaymentAmountSnapshot(invoice: 10000, previous: a.total),
        PaymentAmountMode.receipt,
        parseMoneyInput('33.33')!,
      );
      expect(b.total, 6666);
      final approve = previewFullApproval(
        PaymentAmountSnapshot(invoice: 10000, previous: b.total),
      ).preview!;
      expect(approve.receipt, 3334);
      expect(approve.total, 10000);
      expect(approve.remaining, 0);
    });

    test('approval after partials confirms the full invoice', () {
      const s = PaymentAmountSnapshot(invoice: 20000, previous: 11000);
      expect(
        previewFullApproval(s).preview,
        const PaymentReviewPreview(receipt: 9000, total: 20000, remaining: 0),
      );
    });

    test('rejection never moves the confirmed totals', () {
      const s = PaymentAmountSnapshot(invoice: 20000, previous: 11000);
      expect(
        previewRejection(s).preview,
        const PaymentReviewPreview(receipt: 0, total: 11000, remaining: 9000),
      );
    });
  });

  group('command validation', () {
    const s = PaymentAmountSnapshot(invoice: 20000, previous: 6000);

    test('a valid partial / approve / reject passes', () {
      expect(validatePaymentReviewCommand(_command(), s), isNull);
      expect(
        validatePaymentReviewCommand(
          _command(
            decision: PaymentReviewWire.approve,
            mode: null,
            amount: null,
          ),
          s,
        ),
        isNull,
      );
      expect(
        validatePaymentReviewCommand(
          _command(
            decision: PaymentReviewWire.reject,
            mode: null,
            amount: null,
          ),
          s,
        ),
        isNull,
      );
    });

    test('amounts are partial-only', () {
      expect(
        validatePaymentReviewCommand(
          _command(decision: PaymentReviewWire.approve),
          s,
        ),
        'لا يُقبل مبلغ مع قرار الاعتماد أو الرفض',
      );
      expect(
        validatePaymentReviewCommand(_command(mode: null), s),
        'اختر طريقة إدخال المبلغ',
      );
    });

    test('proof binding, ids and notes are checked', () {
      expect(validatePaymentReviewCommand(_command(proof: ''), s), isNotNull);
      expect(
        validatePaymentReviewCommand(_command(proof: 'a/b.jpg'), s),
        isNotNull,
      );
      expect(
        validatePaymentReviewCommand(_command(paymentId: ' '), s),
        isNotNull,
      );
      expect(
        validatePaymentReviewCommand(_command(decision: 'paid'), s),
        isNotNull,
      );
      expect(
        validatePaymentReviewCommand(_command(notes: 'x' * 501), s),
        'الملاحظات طويلة جداً',
      );
      expect(
        validatePaymentReviewCommand(_command(amount: 14000), s),
        contains('الاعتماد الكامل'),
      );
    });

    test('commands normalize notes and proof name', () {
      expect(
        _command(notes: '  ok  ', proof: ' 1.jpg '),
        _command(notes: 'ok', proof: '1.jpg'),
      );
      expect(_command(notes: null), _command(notes: '   '));
    });
  });

  group('requestId', () {
    test('Random.secure ids match the callable pattern and differ', () {
      final ids = {for (var i = 0; i < 50; i++) newPaymentReviewRequestId()};
      expect(ids, hasLength(50));
      for (final id in ids) {
        expect(kPaymentReviewRequestIdPattern.hasMatch(id), isTrue, reason: id);
      }
      expect(
        newPaymentReviewRequestId(Random(1)),
        newPaymentReviewRequestId(Random(1)),
      );
    });

    test('an identical retry reuses the id; any change gets a new one', () {
      var n = 0;
      final ids = PaymentReviewRequestIds(
        generate: () => 'req_${n++}_padding_xx',
      );
      final first = ids.idFor(_command());
      expect(ids.idFor(_command()), first);
      expect(ids.idFor(_command(notes: '  ')), first);

      for (final changed in [
        _command(amount: 6100),
        _command(mode: PaymentAmountMode.cumulative),
        _command(notes: 'n'),
        _command(proof: '1790000000001.jpg'),
        _command(decision: PaymentReviewWire.reject, mode: null, amount: null),
      ]) {
        final id = ids.idFor(changed);
        expect(id, isNot(first), reason: '$changed');
        expect(ids.idFor(_command()), isNot(id));
      }
    });

    test('ids are tracked per payment and reset once settled', () {
      var n = 0;
      final ids = PaymentReviewRequestIds(
        generate: () => 'req_${n++}_padding_xx',
      );
      final p1 = ids.idFor(_command());
      final p2 = ids.idFor(_command(paymentId: 'p2'));
      expect(p2, isNot(p1));
      expect(ids.idFor(_command()), p1);
      ids.settle('p1');
      expect(ids.idFor(_command()), isNot(p1));
      expect(ids.idFor(_command(paymentId: 'p2')), p2);
      ids.clear();
      expect(ids.idFor(_command(paymentId: 'p2')), isNot(p2));
    });
  });

  group('reviewPaymentProof payload', () {
    test('partial sends mode + major-unit value + idempotency fields', () {
      expect(
        reviewPaymentProofPayload(
          _command(amount: 3333, notes: ' ok '),
          requestId: 'req_0123456789abcdef',
        ),
        {
          'paymentId': 'p1',
          'decision': 'partial',
          'notes': 'ok',
          'requestId': 'req_0123456789abcdef',
          'expectedProofFileName': '1790000000000.jpg',
          'amountMode': 'receipt',
          'amountValue': 33.33,
        },
      );
    });

    test('approve / reject never send amounts or legacy fields', () {
      for (final decision in [
        PaymentReviewWire.approve,
        PaymentReviewWire.reject,
      ]) {
        final payload = reviewPaymentProofPayload(
          _command(decision: decision, mode: null, amount: null),
          requestId: 'req_0123456789abcdef',
        );
        expect(
          payload.keys,
          unorderedEquals([
            'paymentId',
            'decision',
            'requestId',
            'expectedProofFileName',
          ]),
        );
      }
    });
  });

  test('Dart constants match functions/src/billing/paymentReview.ts', () {
    final ts = File(
      'functions/src/billing/paymentReview.ts',
    ).readAsStringSync();
    expect(
      ts,
      contains('PROOF_CHANGED_MESSAGE = "$kPaymentProofChangedMessage"'),
    );
    expect(
      ts,
      contains(
        'REQUEST_ID_PATTERN = /${kPaymentReviewRequestIdPattern.pattern.replaceAll('/', r'\/')}/',
      ),
    );
    expect(
      ts,
      contains('MAX_REVIEW_NOTES_LENGTH = $kPaymentReviewNotesMaxLength'),
    );
    expect(ts, contains('AMOUNT_INPUT_MODES = ["receipt", "cumulative"]'));
    for (final message in kPaymentNoLongerPendingMessages) {
      expect(ts, contains('"$message"'), reason: message);
    }
    expect(ts, contains('replayed: true'));
  });

  group('review response and open commands', () {
    test('replayed / reviewStatus are read; older replies are fresh', () {
      final command = _command();
      expect(
        reviewPaymentProofResult({
          'reviewStatus': 'partial',
          'replayed': true,
        }, command),
        const PaymentReviewResult(
          paymentId: 'p1',
          reviewStatus: 'partial',
          replayed: true,
        ),
      );
      expect(
        reviewPaymentProofResult(null, command),
        const PaymentReviewResult(paymentId: 'p1'),
      );
      expect(
        reviewPaymentProofResult({'replayed': 'true'}, command).replayed,
        isFalse,
      );
    });

    test('the open command is kept verbatim until settled or dropped', () {
      final ids = PaymentReviewRequestIds();
      final first = _command(notes: 'أ');
      ids.idFor(first);
      ids.idFor(_command(paymentId: 'p2'));
      expect(ids.openCommand('p1'), first);
      expect(ids.openCommands.keys, unorderedEquals(['p1', 'p2']));

      ids.retainWhere((c) => c.paymentId == 'p2');
      expect(ids.openCommand('p1'), isNull);
      ids.settle('p2');
      expect(ids.openCommands, isEmpty);
    });
  });

  group('proof cycle', () {
    test('the cycle is part of the intent: another cycle is another id', () {
      var n = 0;
      final ids = PaymentReviewRequestIds(
        generate: () => 'req_${n++}_padding_xx',
      );
      final onA = ids.idFor(_command(cycle: _cycleA));
      expect(ids.idFor(_command(cycle: _cycleA)), onA, reason: 'retry');
      expect(_command(cycle: _cycleA), isNot(_command(cycle: _cycleB)));
      final onB = ids.idFor(_command(cycle: _cycleB));
      expect(onB, isNot(onA));
      expect(ids.openCommand('p1')!.expectedProofCycleId, _cycleB);
    });

    test('targetsProof compares file name and cycle', () {
      final command = _command(cycle: _cycleA);
      expect(
        command.targetsProof(
          fileName: '1790000000000.jpg',
          proofCycleId: _cycleA,
        ),
        isTrue,
      );
      // Same name under a new cycle (A → B → A) is another proof.
      expect(
        command.targetsProof(
          fileName: '1790000000000.jpg',
          proofCycleId: _cycleB,
        ),
        isFalse,
      );
      expect(command.targetsProof(fileName: '1790000000000.jpg'), isFalse);
      expect(
        _command().targetsProof(
          fileName: '1790000000000.jpg',
          proofCycleId: _cycleA,
        ),
        isFalse,
      );
      expect(_command().targetsProof(fileName: '1790000000000.jpg'), isTrue);
    });

    test('a malformed cycle is refused locally; legacy (none) passes', () {
      final snapshot = PaymentAmountSnapshot.fromAmounts(invoiceAmount: 200);
      expect(validatePaymentReviewCommand(_command(), snapshot), isNull);
      expect(
        validatePaymentReviewCommand(_command(cycle: _cycleA), snapshot),
        isNull,
      );
      for (final bad in ['x', 'pc_short', 'AAAAAAAAAAAAAAAAAAAAAAAA']) {
        expect(
          validatePaymentReviewCommand(_command(cycle: bad), snapshot),
          isNotNull,
          reason: bad,
        );
      }
    });

    test('payload carries the cycle only when known', () {
      expect(
        reviewPaymentProofPayload(
          _command(cycle: _cycleA),
          requestId: 'req_0123456789abcdef',
        )['expectedProofCycleId'],
        _cycleA,
      );
      expect(
        reviewPaymentProofPayload(
          _command(),
          requestId: 'req_0123456789abcdef',
        ).containsKey('expectedProofCycleId'),
        isFalse,
      );
    });

    test('cycle-required reply is handled like a changed proof', () {
      expect(isPaymentProofChangedMessage(kPaymentProofChangedMessage), isTrue);
      expect(
        isPaymentProofChangedMessage(kPaymentProofCycleRequiredMessage),
        isTrue,
      );
      final ts = File(
        'functions/src/billing/paymentReview.ts',
      ).readAsStringSync();
      expect(ts, contains('"$kPaymentProofCycleRequiredMessage"'));
      expect(
        ts,
        contains(r'PROOF_CYCLE_ID_PATTERN = /^pc_[A-Za-z0-9_-]{16,64}$/'),
      );
    });
  });
}
