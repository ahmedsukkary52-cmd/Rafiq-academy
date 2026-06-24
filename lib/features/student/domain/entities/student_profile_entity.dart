import 'package:equatable/equatable.dart';

class StudentProfileEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final String? halaqaId;
  final String halaqaName; // denormalized - ظهر في التصميم "حلقة المتقدمين"
  final String currentPlanName;
  final double overallProgressPercent;

  /// عدد الآيات المحفوظة إجمالاً
  final int totalVersesMemorized;

  /// عدد الأجزاء المكتملة
  final int completedJuz;

  /// النقاط المتراكمة (ظهرت في التصميم "480 نقطة")
  final int points;

  /// أيام الالتزام المتتالية - "streak" (ظهر في التصميم "15 يوم متتالي")
  final int streakDays;

  /// مستوى الطالب داخل الحلقة (1، 2، 3...) - ظهر في التصميم
  final int level;

  final int totalStars;
  final List<String> badges;

  const StudentProfileEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.halaqaId,
    this.halaqaName = '',
    required this.currentPlanName,
    required this.overallProgressPercent,
    this.totalVersesMemorized = 0,
    this.completedJuz = 0,
    this.points = 0,
    this.streakDays = 0,
    this.level = 1,
    required this.totalStars,
    required this.badges,
  });

  /// هدف الأسبوع: إجمالي الآيات المطلوب في الخطة الأسبوعية
  /// (هيتحسب لاحقاً من reviewSchedule، حطيناه كـ helper هنا)
  bool get hasActiveStreak => streakDays > 0;

  @override
  List<Object?> get props => [
    uid,
    name,
    profileImageUrl,
    halaqaId,
    halaqaName,
    currentPlanName,
    overallProgressPercent,
    totalVersesMemorized,
    completedJuz,
    points,
    streakDays,
    level,
    totalStars,
    badges,
  ];
}
