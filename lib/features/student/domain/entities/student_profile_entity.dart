import 'package:equatable/equatable.dart';

class StudentProfileEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final String? phone;
  final String? halaqaId;
  final String halaqaName; // denormalized - ظهر في التصميم "حلقة المتقدمين"
  final String currentPlanName;

  /// نسبة تقدم السورة الحالية فقط:
  /// (آيات محفوظة في السورة الحالية / إجمالي آياتها) × 100
  /// يُحدَّث من نظام خطة الحفظ لاحقاً — الصفحة تقرأه فقط ولا تحسبه.
  final double overallProgressPercent;

  /// عدد الآيات المحفوظة إجمالاً (كل السور)
  final int totalVersesMemorized;

  /// عدد الأجزاء المكتملة
  final int completedJuz;

  /// عدد السور التي اكتملت 100% — عداد مستقل عن نسبة السورة الحالية
  final int completedSurahs;

  /// النقاط المتراكمة (ظهرت في التصميم "480 نقطة")
  final int points;

  /// أيام الالتزام المتتالية - "streak" (ظهر في التصميم "15 يوم متتالي")
  final int streakDays;

  /// مستوى الطالب داخل الحلقة (1، 2، 3...) - ظهر في التصميم
  final int level;

  final int totalStars;
  final List<String> badges;

  /// عملات الطالب (منفصلة عن points) - تُستخدم لفتح شخصيات جديدة
  final int coins;

  /// الشخصية (avatar) المختارة حالياً لتمثيل الطالب في رحلة الحفظ
  final String avatarId;

  /// كل الشخصيات اللي الطالب فتحها (المجانية + المشتراة بالعملات)
  final List<String> unlockedAvatarIds;

  final DateTime? createdAt;

  const StudentProfileEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.phone,
    this.halaqaId,
    this.halaqaName = '',
    required this.currentPlanName,
    required this.overallProgressPercent,
    this.totalVersesMemorized = 0,
    this.completedJuz = 0,
    this.completedSurahs = 0,
    this.points = 0,
    this.streakDays = 0,
    this.level = 1,
    required this.totalStars,
    required this.badges,
    this.coins = 0,
    this.avatarId = 'fox',
    this.unlockedAvatarIds = const ['fox', 'panda', 'lion', 'rabbit', 'owl'],
    this.createdAt,
  });

  /// هدف الأسبوع: إجمالي الآيات المطلوب في الخطة الأسبوعية
  /// (هيتحسب لاحقاً من reviewSchedule، حطيناه كـ helper هنا)
  bool get hasActiveStreak => streakDays > 0;

  StudentProfileEntity copyWith({
    int? coins,
    String? avatarId,
    List<String>? unlockedAvatarIds,
  }) {
    return StudentProfileEntity(
      uid: uid,
      name: name,
      profileImageUrl: profileImageUrl,
      phone: phone,
      halaqaId: halaqaId,
      halaqaName: halaqaName,
      currentPlanName: currentPlanName,
      overallProgressPercent: overallProgressPercent,
      totalVersesMemorized: totalVersesMemorized,
      completedJuz: completedJuz,
      completedSurahs: completedSurahs,
      points: points,
      streakDays: streakDays,
      level: level,
      totalStars: totalStars,
      badges: badges,
      coins: coins ?? this.coins,
      avatarId: avatarId ?? this.avatarId,
      unlockedAvatarIds: unlockedAvatarIds ?? this.unlockedAvatarIds,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    name,
    profileImageUrl,
    phone,
    halaqaId,
    halaqaName,
    currentPlanName,
    overallProgressPercent,
    totalVersesMemorized,
    completedJuz,
    completedSurahs,
    points,
    streakDays,
    level,
    totalStars,
    badges,
    coins,
    avatarId,
    unlockedAvatarIds,
    createdAt,
  ];
}
