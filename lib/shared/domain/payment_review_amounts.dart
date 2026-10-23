import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../core/error/failure.dart';

/// Payment-review money + request contract shared by every review surface.
/// Mirrors `functions/src/billing/paymentReview.ts`: money has at most two
/// decimals and is computed in integer minor units; the callable re-validates
/// and stays authoritative.
///
/// - `amountPaidConfirmed` is always the cumulative confirmed total.
/// - `remainingAmount` = invoice − `amountPaidConfirmed`.
/// - `receipt` mode: the entered value is this proof's amount (added to the
///   previous total). `cumulative` mode: the entered value is the new total.
/// - A partial review never reaches the invoice; full approval does that.

/// Exact text of the server's `PROOF_CHANGED_MESSAGE`.
const String kPaymentProofChangedMessage = 'تم تحديث الإيصال، أعد تحميل الصفحة';

/// Exact text of the server's `PROOF_CYCLE_REQUIRED_MESSAGE`: the payment has
/// a server-issued proof cycle the request did not carry.
const String kPaymentProofCycleRequiredMessage =
    'تم تحديث الإيصال، أعد تحميل الصفحة (وإن تكرر ذلك فحدّث التطبيق)';

bool isPaymentProofChangedMessage(String? message) {
  final text = message?.trim();
  return text == kPaymentProofChangedMessage ||
      text == kPaymentProofCycleRequiredMessage;
}

/// Exact server texts (`decidePaymentReview` / `reviewPaymentProofCore`) that
/// mean this proof is no longer awaiting review — possibly reviewed by an
/// earlier delivery of the reviewer's own decision whose response was lost.
const Set<String> kPaymentNoLongerPendingMessages = {
  'لا يوجد إيصال بانتظار المراجعة لهذه الدفعة (ربما تمت مراجعته مسبقاً)',
  'تم سداد هذه الدفعة بالفعل',
  'تمت مراجعة هذا الإيصال مسبقاً',
};

bool isPaymentNoLongerPendingMessage(String? message) =>
    kPaymentNoLongerPendingMessages.contains(message?.trim());

const String kPaymentNoLongerPendingNotice =
    'لم تعد هذه الدفعة بانتظار المراجعة (ربما سُجّل القرار مسبقاً) — '
    'تم تحديث القائمة';

const String kPaymentReviewReplayedMessage =
    'سبق تسجيل هذا القرار — تم تحديث القائمة';

const String kPaymentReviewBusyMessage =
    'مراجعة دفعة أخرى قيد الإرسال — انتظر انتهاءها';

/// How a failed review ends locally.
enum PaymentReviewFailureKind {
  /// Refused before any call (use-case validation): nothing reached the server.
  rejectedLocally,

  /// The reviewed proof was replaced; never re-sent against the new one.
  proofChanged,

  /// The proof is no longer pending: reload, never re-send.
  noLongerPending,

  /// Outcome unknown (network, timeout, other server error): the same
  /// command may be retried with the same `requestId`.
  unresolved,
}

PaymentReviewFailureKind paymentReviewFailureKind(Failure failure) {
  if (failure is ValidationFailure) {
    return PaymentReviewFailureKind.rejectedLocally;
  }
  if (isPaymentProofChangedMessage(failure.message)) {
    return PaymentReviewFailureKind.proofChanged;
  }
  if (isPaymentNoLongerPendingMessage(failure.message)) {
    return PaymentReviewFailureKind.noLongerPending;
  }
  return PaymentReviewFailureKind.unresolved;
}

/// What `reviewPaymentProof` answered. [replayed]: the server returned its
/// stored result for an earlier delivery of the same request, so the current
/// row may already belong to a newer review cycle.
class PaymentReviewResult extends Equatable {
  final String paymentId;
  final String reviewStatus;
  final bool replayed;

  const PaymentReviewResult({
    required this.paymentId,
    this.reviewStatus = '',
    this.replayed = false,
  });

  @override
  List<Object?> get props => [paymentId, reviewStatus, replayed];
}

const int kPaymentReviewNotesMaxLength = 500;

abstract final class PaymentReviewWire {
  static const String approve = 'approve';
  static const String reject = 'reject';
  static const String partial = 'partial';

  static const Set<String> decisions = {approve, reject, partial};
}

/// Same rule as the server's `toMinorUnits`: finite, at most 2 decimals,
/// safe integer. `null` for anything else.
int? moneyToMinorUnits(num? value) {
  if (value == null) return null;
  final v = value.toDouble();
  if (!v.isFinite) return null;
  final scaled = v * 100;
  final units = scaled.round();
  if ((scaled - units).abs() > 1e-6 || units.abs() > 9007199254740991) {
    return null;
  }
  return units;
}

double minorUnitsToMoney(int units) => units / 100;

final RegExp _moneyInput = RegExp(r'^\d{1,9}(\.\d{1,2})?$');

/// Parses typed money exactly (no floating point): Western or Arabic-Indic
/// digits, `.` or `٫` as the decimal separator, at most 2 decimals.
int? parseMoneyInput(String raw) {
  final buffer = StringBuffer();
  for (final code in raw.trim().runes) {
    if (code >= 0x0660 && code <= 0x0669) {
      buffer.writeCharCode(0x30 + code - 0x0660);
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      buffer.writeCharCode(0x30 + code - 0x06F0);
    } else if (code == 0x066B) {
      buffer.write('.');
    } else {
      buffer.writeCharCode(code);
    }
  }
  final text = buffer.toString();
  if (!_moneyInput.hasMatch(text)) return null;
  final parts = text.split('.');
  final fraction = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return int.parse(parts[0]) * 100 + fraction;
}

/// `6000` → `60`, `3350` → `33.50`.
String formatMinorUnits(int units) {
  final sign = units < 0 ? '-' : '';
  final abs = units.abs();
  final whole = abs ~/ 100;
  final fraction = abs % 100;
  return fraction == 0
      ? '$sign$whole'
      : '$sign$whole.${fraction.toString().padLeft(2, '0')}';
}

String formatMoneyAmount(double amount) {
  final units = moneyToMinorUnits(amount);
  return units == null ? amount.toStringAsFixed(2) : formatMinorUnits(units);
}

enum PaymentAmountMode { receipt, cumulative }

extension PaymentAmountModeX on PaymentAmountMode {
  String get wire => switch (this) {
    PaymentAmountMode.receipt => 'receipt',
    PaymentAmountMode.cumulative => 'cumulative',
  };

  String get label => switch (this) {
    PaymentAmountMode.receipt => 'قيمة الإيصال الحالي',
    PaymentAmountMode.cumulative => 'الإجمالي المؤكد حتى الآن',
  };
}

/// Invoice + previously confirmed total of one payment, in minor units.
/// Unrepresentable stored values surface through [error], never silently.
class PaymentAmountSnapshot extends Equatable {
  final int invoice;
  final int previous;

  const PaymentAmountSnapshot({required this.invoice, this.previous = 0});

  factory PaymentAmountSnapshot.fromAmounts({
    required double invoiceAmount,
    double? amountPaidConfirmed,
  }) => PaymentAmountSnapshot(
    invoice: moneyToMinorUnits(invoiceAmount) ?? 0,
    previous: amountPaidConfirmed == null
        ? 0
        : moneyToMinorUnits(amountPaidConfirmed) ?? -1,
  );

  String? get error {
    if (invoice <= 0) return 'مبلغ الفاتورة غير صالح';
    if (previous < 0 || previous >= invoice) {
      return 'المبلغ المؤكد السابق لهذه الدفعة غير صالح';
    }
    return null;
  }

  bool get isValid => error == null;

  int get remaining => isValid ? invoice - previous : 0;

  @override
  List<Object?> get props => [invoice, previous];
}

/// Amounts a review would produce, in minor units. [receipt] is what this
/// proof adds; [total] is the new cumulative confirmed total.
class PaymentReviewPreview extends Equatable {
  final int receipt;
  final int total;
  final int remaining;

  const PaymentReviewPreview({
    required this.receipt,
    required this.total,
    required this.remaining,
  });

  @override
  List<Object?> get props => [receipt, total, remaining];
}

class PaymentReviewCheck {
  final PaymentReviewPreview? preview;
  final String? error;

  const PaymentReviewCheck.ok(PaymentReviewPreview this.preview) : error = null;
  const PaymentReviewCheck.invalid(String this.error) : preview = null;

  bool get isValid => error == null;
}

const String _amountInvalidMessage =
    'المبلغ يجب أن يكون أكبر من صفر وبحد أقصى منزلتين عشريتين';

/// Client mirror of the server's partial transition.
PaymentReviewCheck previewPartialPayment({
  required PaymentAmountSnapshot snapshot,
  required PaymentAmountMode mode,
  required int? input,
}) {
  final snapshotError = snapshot.error;
  if (snapshotError != null) return PaymentReviewCheck.invalid(snapshotError);
  if (input == null || input <= 0) {
    return const PaymentReviewCheck.invalid(_amountInvalidMessage);
  }
  final previous = snapshot.previous;
  final int total;
  switch (mode) {
    case PaymentAmountMode.receipt:
      total = previous + input;
    case PaymentAmountMode.cumulative:
      if (input <= previous) {
        return PaymentReviewCheck.invalid(
          'الإجمالي المؤكد يجب أن يكون أكبر من الإجمالي المؤكد سابقاً '
          '(${formatMinorUnits(previous)})',
        );
      }
      total = input;
  }
  if (total > snapshot.invoice) {
    return PaymentReviewCheck.invalid(
      'المبلغ يتجاوز المتبقي من الفاتورة (${formatMinorUnits(snapshot.remaining)})',
    );
  }
  if (total == snapshot.invoice) {
    return const PaymentReviewCheck.invalid(
      'المبلغ يغطي كامل الفاتورة — استخدم الاعتماد الكامل بدل السداد الجزئي',
    );
  }
  return PaymentReviewCheck.ok(
    PaymentReviewPreview(
      receipt: total - previous,
      total: total,
      remaining: snapshot.invoice - total,
    ),
  );
}

/// Full approval confirms the whole invoice whatever was typed anywhere.
PaymentReviewCheck previewFullApproval(PaymentAmountSnapshot snapshot) {
  final error = snapshot.error;
  if (error != null) return PaymentReviewCheck.invalid(error);
  return PaymentReviewCheck.ok(
    PaymentReviewPreview(
      receipt: snapshot.remaining,
      total: snapshot.invoice,
      remaining: 0,
    ),
  );
}

/// Rejection never moves the confirmed totals.
PaymentReviewCheck previewRejection(PaymentAmountSnapshot snapshot) {
  final error = snapshot.error;
  if (error != null) return PaymentReviewCheck.invalid(error);
  return PaymentReviewCheck.ok(
    PaymentReviewPreview(
      receipt: 0,
      total: snapshot.previous,
      remaining: snapshot.remaining,
    ),
  );
}

final RegExp kPaymentReviewRequestIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');
final RegExp _expectedProofFileName = RegExp(r'^[A-Za-z0-9_.-]{1,80}$');

bool isValidExpectedProofFileName(String? name) =>
    _expectedProofFileName.hasMatch(name?.trim() ?? '');

final RegExp _proofCycleId = RegExp(r'^pc_[A-Za-z0-9_-]{16,64}$');

/// Empty = the reviewed item had no server-issued cycle (legacy payment).
bool isValidExpectedProofCycleId(String name) =>
    name.isEmpty || _proofCycleId.hasMatch(name);

/// The full intent of one review submission. Two commands are equal only
/// when every field the server fingerprints is equal.
class PaymentReviewCommand extends Equatable {
  final String paymentId;
  final String decision;
  final String notes;
  final PaymentAmountMode? amountMode;
  final int? amountMinorUnits;
  final String expectedProofFileName;

  /// Server-issued proof cycle the reviewer saw ('' for legacy payments).
  final String expectedProofCycleId;

  PaymentReviewCommand({
    required String paymentId,
    required this.decision,
    String? notes,
    this.amountMode,
    this.amountMinorUnits,
    required String expectedProofFileName,
    String? expectedProofCycleId,
  }) : paymentId = paymentId.trim(),
       notes = notes?.trim() ?? '',
       expectedProofFileName = expectedProofFileName.trim(),
       expectedProofCycleId = expectedProofCycleId?.trim() ?? '';

  bool get isPartial => decision == PaymentReviewWire.partial;

  /// True when this command was built for exactly that proof.
  bool targetsProof({String? fileName, String? proofCycleId}) =>
      expectedProofFileName == (fileName?.trim() ?? '') &&
      expectedProofCycleId == (proofCycleId?.trim() ?? '');

  @override
  List<Object?> get props => [
    paymentId,
    decision,
    notes,
    amountMode,
    amountMinorUnits,
    expectedProofFileName,
    expectedProofCycleId,
  ];
}

/// Local pre-check shared by every review use case.
String? validatePaymentReviewCommand(
  PaymentReviewCommand command,
  PaymentAmountSnapshot snapshot,
) {
  if (command.paymentId.isEmpty ||
      !PaymentReviewWire.decisions.contains(command.decision)) {
    return 'بيانات المراجعة غير صالحة';
  }
  if (!isValidExpectedProofFileName(command.expectedProofFileName) ||
      !isValidExpectedProofCycleId(command.expectedProofCycleId)) {
    return 'لا يوجد إيصال صالح للمراجعة — أعد تحميل الصفحة';
  }
  if (command.notes.length > kPaymentReviewNotesMaxLength) {
    return 'الملاحظات طويلة جداً';
  }
  if (command.isPartial) {
    final mode = command.amountMode;
    if (mode == null) return 'اختر طريقة إدخال المبلغ';
    return previewPartialPayment(
      snapshot: snapshot,
      mode: mode,
      input: command.amountMinorUnits,
    ).error;
  }
  if (command.amountMode != null || command.amountMinorUnits != null) {
    return 'لا يُقبل مبلغ مع قرار الاعتماد أو الرفض';
  }
  return snapshot.error;
}

String newPaymentReviewRequestId([Random? random]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final rng = random ?? Random.secure();
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// One `requestId` per review intent: resubmitting the identical command
/// (retry after a timeout / network error) reuses the id so the server can
/// replay its stored result; any change to the command gets a fresh id.
/// The server's idempotency record and proof binding stay authoritative.
class PaymentReviewRequestIds {
  final String Function() _generate;
  final Map<String, (PaymentReviewCommand, String)> _open = {};

  PaymentReviewRequestIds({String Function()? generate})
    : _generate = generate ?? newPaymentReviewRequestId;

  String idFor(PaymentReviewCommand command) {
    final open = _open[command.paymentId];
    if (open != null && open.$1 == command) return open.$2;
    final id = _generate();
    _open[command.paymentId] = (command, id);
    return id;
  }

  /// The command still awaiting a definitive outcome for [paymentId]; a retry
  /// re-sends exactly this command (same content, same `requestId`).
  PaymentReviewCommand? openCommand(String paymentId) =>
      _open[paymentId.trim()]?.$1;

  Map<String, PaymentReviewCommand> get openCommands => {
    for (final entry in _open.entries) entry.key: entry.value.$1,
  };

  /// The review concluded (or its proof changed): the next one is new.
  void settle(String paymentId) => _open.remove(paymentId.trim());

  /// Drops open commands that no longer match a pending proof.
  void retainWhere(bool Function(PaymentReviewCommand command) keep) =>
      _open.removeWhere((_, open) => !keep(open.$1));

  void clear() => _open.clear();
}
