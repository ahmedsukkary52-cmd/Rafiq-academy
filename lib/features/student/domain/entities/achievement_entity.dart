import 'package:equatable/equatable.dart';

import '../../../awards/domain/entities/award_entities.dart';

enum AchievementType {
  star,
  badge,
  certificate,
  completionBadge,
  performanceStars,
  perfectAttendance,
  studentOfWeek,
  attendance,
  completion,
  performance,
  achievement,
  custom,
}

extension AchievementTypeMapping on AchievementType {
  AwardType? get awardType => switch (this) {
    AchievementType.completionBadge => AwardType.completionBadge,
    AchievementType.performanceStars => AwardType.performanceStars,
    AchievementType.perfectAttendance => AwardType.perfectAttendance,
    AchievementType.studentOfWeek => AwardType.studentOfWeek,
    AchievementType.attendance => AwardType.attendance,
    AchievementType.completion => AwardType.completion,
    AchievementType.performance => AwardType.performance,
    AchievementType.achievement => AwardType.achievement,
    AchievementType.custom => AwardType.custom,
    _ => null,
  };
}

class AchievementEntity extends Equatable {
  final String id;
  final String studentId;
  final AchievementType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final String issuedBy;
  final DateTime date;
  final List<String> recipientStudentIds;

  const AchievementEntity({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    required this.issuedBy,
    required this.date,
    this.recipientStudentIds = const [],
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    type,
    title,
    description,
    imageUrl,
    issuedBy,
    date,
    recipientStudentIds,
  ];
}
