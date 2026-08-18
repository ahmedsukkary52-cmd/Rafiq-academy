import 'package:equatable/equatable.dart';

import '../../../shared/domain/student_at_risk_policy.dart';
import 'entities/parent_entities.dart';

class ParentStaffContact extends Equatable {
  final String uid;
  final String name;
  final String role;
  final String? profileImageUrl;

  const ParentStaffContact({
    required this.uid,
    required this.name,
    required this.role,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [uid, name, role, profileImageUrl];
}

class ParentChildSnapshot extends Equatable {
  final String studentId;
  final String name;
  final String? profileImageUrl;
  final String? halaqaId;
  final String halaqaName;
  final String? teacherId;
  final String teacherName;
  final String? supervisorId;
  final String supervisorName;
  final double overallProgressPercent;
  final int totalVersesMemorized;
  final int streakDays;
  final String? todayAttendanceStatus;
  final bool isAtRisk;
  final RiskSignal? riskSignal;
  final double? attendancePercentInWindow;
  final PaymentStatus? paymentStatus;

  const ParentChildSnapshot({
    required this.studentId,
    required this.name,
    this.profileImageUrl,
    this.halaqaId,
    this.halaqaName = '',
    this.teacherId,
    this.teacherName = '',
    this.supervisorId,
    this.supervisorName = '',
    this.overallProgressPercent = 0,
    this.totalVersesMemorized = 0,
    this.streakDays = 0,
    this.todayAttendanceStatus,
    this.isAtRisk = false,
    this.riskSignal,
    this.attendancePercentInWindow,
    this.paymentStatus,
  });

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'طالب' : trimmed;
  }

  ParentChildSnapshot withPaymentStatus(PaymentStatus? status) {
    return ParentChildSnapshot(
      studentId: studentId,
      name: name,
      profileImageUrl: profileImageUrl,
      halaqaId: halaqaId,
      halaqaName: halaqaName,
      teacherId: teacherId,
      teacherName: teacherName,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      overallProgressPercent: overallProgressPercent,
      totalVersesMemorized: totalVersesMemorized,
      streakDays: streakDays,
      todayAttendanceStatus: todayAttendanceStatus,
      isAtRisk: isAtRisk,
      riskSignal: riskSignal,
      attendancePercentInWindow: attendancePercentInWindow,
      paymentStatus: status,
    );
  }

  @override
  List<Object?> get props => [
    studentId,
    name,
    profileImageUrl,
    halaqaId,
    halaqaName,
    teacherId,
    teacherName,
    supervisorId,
    supervisorName,
    overallProgressPercent,
    totalVersesMemorized,
    streakDays,
    todayAttendanceStatus,
    isAtRisk,
    riskSignal,
    attendancePercentInWindow,
    paymentStatus,
  ];
}

class ParentHousehold extends Equatable {
  final List<ParentChildSnapshot> children;
  final List<ParentStaffContact> staffContacts;

  const ParentHousehold({
    this.children = const [],
    this.staffContacts = const [],
  });

  static const empty = ParentHousehold();

  @override
  List<Object?> get props => [children, staffContacts];
}

class ParentFamilySummary extends Equatable {
  final int childrenCount;
  final int presentTodayCount;
  final int atRiskCount;
  final int overduePaymentsCount;
  final double? averageAttendancePercent;

  const ParentFamilySummary({
    required this.childrenCount,
    required this.presentTodayCount,
    required this.atRiskCount,
    required this.overduePaymentsCount,
    this.averageAttendancePercent,
  });

  static const empty = ParentFamilySummary(
    childrenCount: 0,
    presentTodayCount: 0,
    atRiskCount: 0,
    overduePaymentsCount: 0,
  );

  @override
  List<Object?> get props => [
    childrenCount,
    presentTodayCount,
    atRiskCount,
    overduePaymentsCount,
    averageAttendancePercent,
  ];
}

enum ParentAlertKind { overduePayment, atRiskAbsence, atRiskNoEval }

class ParentAlert extends Equatable {
  final ParentAlertKind kind;
  final String studentId;
  final String studentName;
  final String message;

  const ParentAlert({
    required this.kind,
    required this.studentId,
    required this.studentName,
    required this.message,
  });

  @override
  List<Object?> get props => [kind, studentId, studentName, message];
}

class ParentAttendanceMark extends Equatable {
  final String id;
  final String studentId;
  final String halaqaId;
  final DateTime date;
  final String status;

  const ParentAttendanceMark({
    required this.id,
    required this.studentId,
    required this.halaqaId,
    required this.date,
    required this.status,
  });

  @override
  List<Object?> get props => [id, studentId, halaqaId, date, status];
}

class ParentHouseholdAssembler {
  const ParentHouseholdAssembler._();

  static PaymentStatus? paymentStatusForStudent(
    List<PaymentEntity> payments,
    String studentId,
  ) {
    PaymentStatus? worst;
    for (final payment in payments) {
      if (payment.studentId != studentId) continue;
      worst = _worsePayment(worst, payment.status);
    }
    return worst;
  }

  static List<ParentChildSnapshot> withPayments({
    required List<ParentChildSnapshot> children,
    required List<PaymentEntity> payments,
  }) {
    return [
      for (final child in children)
        child.withPaymentStatus(
          paymentStatusForStudent(payments, child.studentId),
        ),
    ];
  }

  static ParentFamilySummary summarize({
    required List<ParentChildSnapshot> children,
    required List<PaymentEntity> payments,
  }) {
    var presentToday = 0;
    var atRisk = 0;
    final percents = <double>[];
    for (final child in children) {
      if (child.todayAttendanceStatus == 'present' ||
          child.todayAttendanceStatus == 'late') {
        presentToday++;
      }
      if (child.isAtRisk) atRisk++;
      final percent = child.attendancePercentInWindow;
      if (percent != null) percents.add(percent);
    }
    final overdue = payments
        .where((p) => p.status == PaymentStatus.overdue)
        .length;
    return ParentFamilySummary(
      childrenCount: children.length,
      presentTodayCount: presentToday,
      atRiskCount: atRisk,
      overduePaymentsCount: overdue,
      averageAttendancePercent: percents.isEmpty
          ? null
          : percents.reduce((a, b) => a + b) / percents.length,
    );
  }

  static List<ParentAlert> alerts({
    required List<ParentChildSnapshot> children,
    required List<PaymentEntity> payments,
  }) {
    final byId = {for (final c in children) c.studentId: c};
    final result = <ParentAlert>[];

    for (final payment in payments) {
      if (payment.status != PaymentStatus.overdue) continue;
      final child = byId[payment.studentId];
      final name = child?.displayName ?? 'طالب';
      result.add(
        ParentAlert(
          kind: ParentAlertKind.overduePayment,
          studentId: payment.studentId,
          studentName: name,
          message: 'مستحق متأخر لـ $name',
        ),
      );
    }

    for (final child in children) {
      if (child.riskSignal == RiskSignal.repeatedAbsence) {
        result.add(
          ParentAlert(
            kind: ParentAlertKind.atRiskAbsence,
            studentId: child.studentId,
            studentName: child.displayName,
            message: 'غياب متكرر لـ ${child.displayName} خلال آخر 14 يوماً',
          ),
        );
      } else if (child.riskSignal == RiskSignal.noRecentEvaluation) {
        result.add(
          ParentAlert(
            kind: ParentAlertKind.atRiskNoEval,
            studentId: child.studentId,
            studentName: child.displayName,
            message: 'لا يوجد تقييم معتمد حديث لـ ${child.displayName}',
          ),
        );
      }
    }
    return result;
  }

  static PaymentStatus? _worsePayment(PaymentStatus? current, PaymentStatus next) {
    if (current == null) return next;
    const rank = {
      PaymentStatus.paid: 0,
      PaymentStatus.due: 1,
      PaymentStatus.overdue: 2,
    };
    return (rank[next] ?? 0) >= (rank[current] ?? 0) ? next : current;
  }
}
