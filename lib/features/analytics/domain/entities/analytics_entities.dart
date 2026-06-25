import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HalaqaAnalyticsEntity - ملخص تحليلات الحلقة (الأرقام الكبيرة في الأعلى)
// ══════════════════════════════════════════════════════════════════════════════

class HalaqaAnalyticsEntity extends Equatable {
  final String halaqaId;

  /// متوسط درجات الحفظ لكل الطلاب كنسبة مئوية
  final double averagePerformancePercent;

  /// نسبة الحضور الكلية للحلقة في الفترة المحددة
  final double attendancePercent;

  /// إجمالي عدد الطلاب النشطين
  final int totalStudents;

  /// توزيع الطلاب على مستويات الأداء
  final Map<String, int> performanceDistribution;

  // مثال: {'ممتاز': 19, 'جيد جداً': 13, 'جيد': 6, 'يحتاج تحسين': 4}

  /// حضور كل يوم في الأسبوع الأخير (للـ bar chart)
  /// key = اسم اليوم، value = نسبة الحضور
  final Map<String, double> weeklyAttendance;

  const HalaqaAnalyticsEntity({
    required this.halaqaId,
    required this.averagePerformancePercent,
    required this.attendancePercent,
    required this.totalStudents,
    required this.performanceDistribution,
    required this.weeklyAttendance,
  });

  @override
  List<Object?> get props => [
    halaqaId,
    averagePerformancePercent,
    attendancePercent,
    totalStudents,
    performanceDistribution,
    weeklyAttendance,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// AtRiskStudentEntity - طالب يحتاج متابعة عاجلة
// ══════════════════════════════════════════════════════════════════════════════

/// سبب الخطر - بيحدد الأيقونة والنص اللي بيظهر في لوحة التحليلات
enum RiskReason { repeatedAbsence, lowPerformance, noRecentEvaluation }

extension RiskReasonLabel on RiskReason {
  String get label => switch (this) {
    RiskReason.repeatedAbsence => 'غيابات متتالية',
    RiskReason.lowPerformance => 'أداء منخفض',
    RiskReason.noRecentEvaluation => 'لم يُقيَّم مؤخراً',
  };
}

class AtRiskStudentEntity extends Equatable {
  final String studentId;
  final String studentName;
  final String? profileImageUrl;
  final RiskReason reason;
  final String detail; // مثال: "٣ غيابات متتالية"

  const AtRiskStudentEntity({
    required this.studentId,
    required this.studentName,
    this.profileImageUrl,
    required this.reason,
    required this.detail,
  });

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    profileImageUrl,
    reason,
    detail,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// TopStudentEntity - الطلاب المتفوقون
// ══════════════════════════════════════════════════════════════════════════════

class TopStudentEntity extends Equatable {
  final String studentId;
  final String studentName;
  final String? profileImageUrl;
  final double performancePercent;
  final int rank;

  const TopStudentEntity({
    required this.studentId,
    required this.studentName,
    this.profileImageUrl,
    required this.performancePercent,
    required this.rank,
  });

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    profileImageUrl,
    performancePercent,
    rank,
  ];
}
