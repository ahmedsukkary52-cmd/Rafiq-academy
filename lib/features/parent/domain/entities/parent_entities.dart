import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AbsenceRequestEntity - طلب استئذان من ولي الأمر
// ══════════════════════════════════════════════════════════════════════════════

enum AbsenceRequestStatus { pending, approved, rejected }

class AbsenceRequestEntity extends Equatable {
  final String id;
  final String studentId;
  final String requestedBy;
  final DateTime date;
  final String reason;
  final AbsenceRequestStatus status;
  final String? reviewedBy;

  const AbsenceRequestEntity({
    required this.id,
    required this.studentId,
    required this.requestedBy,
    required this.date,
    required this.reason,
    required this.status,
    this.reviewedBy,
  });

  @override
  List<Object?> get props =>
      [id, studentId, requestedBy, date, reason, status, reviewedBy];
}

// ══════════════════════════════════════════════════════════════════════════════
// PaymentEntity - الرسوم والاشتراكات
// ══════════════════════════════════════════════════════════════════════════════

enum PaymentStatus { paid, due, overdue }

class PaymentEntity extends Equatable {
  final String id;
  final String studentId;
  final String parentId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidAt;
  final PaymentStatus status;
  final String? method;

  const PaymentEntity({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.amount,
    required this.dueDate,
    this.paidAt,
    required this.status,
    this.method,
  });

  @override
  List<Object?> get props =>
      [id, studentId, parentId, amount, dueDate, paidAt, status, method];
}

// ══════════════════════════════════════════════════════════════════════════════
// WeeklyReportEntity - التقرير الأسبوعي لولي الأمر
// ══════════════════════════════════════════════════════════════════════════════

class WeeklyReportEntity extends Equatable {
  final String studentId;
  final String studentName;
  final DateTime weekStart;
  final int totalVersesMemorized;
  final int attendedSessions;
  final int totalSessions;
  final String teacherNotes;

  const WeeklyReportEntity({
    required this.studentId,
    required this.studentName,
    required this.weekStart,
    required this.totalVersesMemorized,
    required this.attendedSessions,
    required this.totalSessions,
    required this.teacherNotes,
  });

  double get attendancePercent =>
      totalSessions == 0 ? 0 : (attendedSessions / totalSessions) * 100;

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    weekStart,
    totalVersesMemorized,
    attendedSessions,
    totalSessions,
    teacherNotes,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// PaymentInitiationEntity
// ══════════════════════════════════════════════════════════════════════════════

/// نتيجة بدء عملية دفع عند Paymob - بنرجّع منها رابط صفحة الدفع الجاهزة
/// (checkout) اللي الـ UI هيفتحه (في WebView مثلاً) لما نبني الشاشات.
class PaymentInitiationEntity extends Equatable {
  final String clientSecret;
  final String publicKey;

  const PaymentInitiationEntity({
    required this.clientSecret,
    required this.publicKey,
  });

  /// رابط صفحة الدفع الموحّدة الجاهزة من Paymob (Unified Checkout)
  String get checkoutUrl =>
      'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey&clientSecret=$clientSecret';

  @override
  List<Object?> get props => [clientSecret, publicKey];
}