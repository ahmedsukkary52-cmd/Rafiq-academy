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
}

extension AchievementTypeMapping on AchievementType {
  AwardType? get awardType => switch (this) {
    AchievementType.completionBadge => AwardType.completionBadge,
    AchievementType.performanceStars => AwardType.performanceStars,
    AchievementType.perfectAttendance => AwardType.perfectAttendance,
    AchievementType.studentOfWeek => AwardType.studentOfWeek,
    _ => null,
  };
}

class AchievementEntity extends Equatable {
  final String id;
  final String studentId;
  final AchievementType type;
  final String title;
  final String issuedBy;
  final DateTime date;

  const AchievementEntity({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.issuedBy,
    required this.date,
  });

  @override
  List<Object?> get props => [id, studentId, type, title, issuedBy, date];
}
