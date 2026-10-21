import 'dart:math';

import 'package:equatable/equatable.dart';

/// Idempotency key for adminCreateHalaqa (`^[A-Za-z0-9_-]{8,64}$`): one key
/// per create form, so a retried submit converges on the same Halaqa.
String newHalaqaRequestId([Random? random]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final rng = random ?? Random.secure();
  return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// Directory row for Admin operational pickers (users/{uid}).
class AdminDirectoryUser extends Equatable {
  final String uid;
  final String name;
  final String role;
  final bool isActive;
  final String email;

  const AdminDirectoryUser({
    required this.uid,
    required this.name,
    required this.role,
    this.isActive = true,
    this.email = '',
  });

  String get displayName => name.trim().isEmpty ? uid : name.trim();

  @override
  List<Object?> get props => [uid, name, role, isActive, email];
}

/// Weekly slot intent for adminCreateHalaqa / adminAddHalaqaSlot.
/// The server canonicalizes the day label and validates HH:mm + end > start.
class HalaqaSlotInput extends Equatable {
  final String day;
  final String startTime;
  final String endTime;

  const HalaqaSlotInput({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  Map<String, String> toMap() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
  };

  @override
  List<Object?> get props => [day, startTime, endTime];
}

enum ParentLinkOperation { link, unlink }

extension ParentLinkOperationWire on ParentLinkOperation {
  String get wire => switch (this) {
    ParentLinkOperation.link => 'link',
    ParentLinkOperation.unlink => 'unlink',
  };
}

/// Result of adminLinkParentChild (idempotent: [changed] false on no-op).
class ParentLinkResult extends Equatable {
  final List<String> childrenIds;
  final bool changed;

  const ParentLinkResult({required this.childrenIds, required this.changed});

  @override
  List<Object?> get props => [childrenIds, changed];
}

/// Outcome of `setHalaqaMeetingLink` (`unchanged` when nothing was written).
enum MeetingLinkChange { set, update, clear, unchanged }

MeetingLinkChange meetingLinkChangeFromWire(Object? raw) => switch (raw) {
  'set' => MeetingLinkChange.set,
  'update' => MeetingLinkChange.update,
  'clear' => MeetingLinkChange.clear,
  _ => MeetingLinkChange.unchanged,
};

String meetingLinkChangeMessage(MeetingLinkChange change) => switch (change) {
  MeetingLinkChange.set => 'تم حفظ رابط الاجتماع',
  MeetingLinkChange.update => 'تم تحديث رابط الاجتماع',
  MeetingLinkChange.clear => 'تم حذف رابط الاجتماع',
  MeetingLinkChange.unchanged => 'لم يتغير رابط الاجتماع',
};

enum PaymentReviewDecision { approve, reject, partial }

extension PaymentReviewDecisionWire on PaymentReviewDecision {
  String get wire => switch (this) {
    PaymentReviewDecision.approve => 'approve',
    PaymentReviewDecision.reject => 'reject',
    PaymentReviewDecision.partial => 'partial',
  };

  String get label => switch (this) {
    PaymentReviewDecision.approve => 'اعتماد السداد',
    PaymentReviewDecision.reject => 'رفض الإيصال',
    PaymentReviewDecision.partial => 'سداد جزئي',
  };
}

/// Pending payment proof awaiting Admin / scoped Supervisor review (P0-03).
/// Read-only invoice context; the review conclusion is reviewPaymentProof's.
class PaymentReviewItem extends Equatable {
  final String paymentId;
  final String parentId;
  final String studentId;
  final String studentName;
  final double amount;
  final String currency;
  final String periodKey;
  final DateTime? dueDate;
  final String status;
  final String reviewStatus;
  final String? proofDownloadUrl;
  final String? proofFileName;
  final DateTime? proofSubmittedAt;

  const PaymentReviewItem({
    required this.paymentId,
    required this.parentId,
    required this.studentId,
    required this.amount,
    this.studentName = '',
    this.currency = '',
    this.periodKey = '',
    this.dueDate,
    this.status = '',
    this.reviewStatus = '',
    this.proofDownloadUrl,
    this.proofFileName,
    this.proofSubmittedAt,
  });

  bool get hasProofImage => (proofDownloadUrl?.trim() ?? '').isNotEmpty;

  PaymentReviewItem withStudentName(String name) => PaymentReviewItem(
    paymentId: paymentId,
    parentId: parentId,
    studentId: studentId,
    amount: amount,
    studentName: name,
    currency: currency,
    periodKey: periodKey,
    dueDate: dueDate,
    status: status,
    reviewStatus: reviewStatus,
    proofDownloadUrl: proofDownloadUrl,
    proofFileName: proofFileName,
    proofSubmittedAt: proofSubmittedAt,
  );

  @override
  List<Object?> get props => [
    paymentId,
    parentId,
    studentId,
    studentName,
    amount,
    currency,
    periodKey,
    dueDate,
    status,
    reviewStatus,
    proofDownloadUrl,
    proofFileName,
    proofSubmittedAt,
  ];
}

/// Client-side pre-check mirroring the server rule for a partial amount
/// (0 < confirmed < invoice amount). The callable remains authoritative.
String? validatePartialAmount({
  required double invoiceAmount,
  required double? confirmed,
}) {
  if (confirmed == null || !confirmed.isFinite) {
    return 'أدخل المبلغ المؤكد';
  }
  if (confirmed <= 0 || confirmed >= invoiceAmount) {
    return 'المبلغ يجب أن يكون أكبر من صفر وأقل من قيمة الفاتورة';
  }
  return null;
}

/// HH:mm validator shared by the slot form (server re-validates).
bool isValidClockTime(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) return false;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  return h >= 0 && h <= 23 && min >= 0 && min <= 59;
}

int _minutes(String hhmm) {
  final parts = hhmm.trim().split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Returns an Arabic error for an invalid slot, or `null` when acceptable.
String? validateSlotInput(HalaqaSlotInput slot) {
  if (slot.day.trim().isEmpty) return 'اختر يوم الموعد';
  if (!isValidClockTime(slot.startTime) || !isValidClockTime(slot.endTime)) {
    return 'أدخل الوقت بصيغة HH:mm';
  }
  if (_minutes(slot.endTime) <= _minutes(slot.startTime)) {
    return 'وقت النهاية يجب أن يكون بعد وقت البداية';
  }
  return null;
}

/// Canonical Arabic weekday labels accepted by the schedule callables.
const List<String> kHalaqaDayLabels = [
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];
