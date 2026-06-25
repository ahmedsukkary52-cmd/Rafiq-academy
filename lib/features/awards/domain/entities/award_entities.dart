import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AwardType - أنواع الجوائز الأربعة الظاهرة في التصميم
// ══════════════════════════════════════════════════════════════════════════════

enum AwardType {
  completionBadge, // شارة الإتمام  - ختم سورة أو جزء
  performanceStars, // نجوم الأداء   - منح نجوم للتحفيظ
  perfectAttendance, // حضور مثالي   - شهر بدون غياب
  studentOfWeek, // طالب الأسبوع  - تميز أسبوعي
}

extension AwardTypeInfo on AwardType {
  String get title => switch (this) {
    AwardType.completionBadge => 'شارة الإتمام',
    AwardType.performanceStars => 'نجوم الأداء',
    AwardType.perfectAttendance => 'حضور مثالي',
    AwardType.studentOfWeek => 'طالب الأسبوع',
  };

  String get description => switch (this) {
    AwardType.completionBadge => 'ختم سورة أو جزء',
    AwardType.performanceStars => 'منح نجوم للتحفيظ',
    AwardType.perfectAttendance => 'شهر بدون غياب',
    AwardType.studentOfWeek => 'تميز أسبوعي',
  };

  String get firestoreKey => switch (this) {
    AwardType.completionBadge => 'completion_badge',
    AwardType.performanceStars => 'performance_stars',
    AwardType.perfectAttendance => 'perfect_attendance',
    AwardType.studentOfWeek => 'student_of_week',
  };

  static AwardType fromKey(String key) => switch (key) {
    'completion_badge' => AwardType.completionBadge,
    'performance_stars' => AwardType.performanceStars,
    'perfect_attendance' => AwardType.perfectAttendance,
    'student_of_week' => AwardType.studentOfWeek,
    _ => AwardType.studentOfWeek,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// GrantedAwardEntity - سجل جائزة ممنوحة لطالب
// ══════════════════════════════════════════════════════════════════════════════

class GrantedAwardEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentImageUrl;
  final AwardType type;

  /// نص إضافي اختياري، مثل "ختم جزء تبارك" أو "نجمتان للتحفيظ"
  final String? note;

  final String grantedBy;
  final String halaqaId;
  final DateTime grantedAt;

  const GrantedAwardEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentImageUrl,
    required this.type,
    this.note,
    required this.grantedBy,
    required this.halaqaId,
    required this.grantedAt,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    type,
    note,
    grantedBy,
    halaqaId,
    grantedAt,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// CertificateDataEntity - بيانات الشهادة اللي بتتمرر لـ PDF generator
// ══════════════════════════════════════════════════════════════════════════════

class CertificateDataEntity extends Equatable {
  final String studentName;
  final String halaqaName;
  final String academyName;
  final String achievement; // مثال: "إتمام حفظ جزء تبارك كاملاً"
  final DateTime date;
  final String teacherName;

  const CertificateDataEntity({
    required this.studentName,
    required this.halaqaName,
    required this.academyName,
    required this.achievement,
    required this.date,
    required this.teacherName,
  });

  @override
  List<Object?> get props => [
    studentName,
    halaqaName,
    academyName,
    achievement,
    date,
    teacherName,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// AwardsStatsEntity - إحصائيات لوحة الجوائز (الأرقام في الأعلى)
// ══════════════════════════════════════════════════════════════════════════════

class AwardsStatsEntity extends Equatable {
  final int totalRecipients; // إجمالي الطلاب المستفيدين
  final int thisMonthCount; // عدد الجوائز هذا الشهر
  final int totalAwardsCount; // إجمالي الجوائز الممنوحة

  const AwardsStatsEntity({
    required this.totalRecipients,
    required this.thisMonthCount,
    required this.totalAwardsCount,
  });

  @override
  List<Object?> get props => [
    totalRecipients,
    thisMonthCount,
    totalAwardsCount,
  ];
}
