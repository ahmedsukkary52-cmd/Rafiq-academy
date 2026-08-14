import '../../awards/domain/entities/award_entities.dart';
import 'entities/achievement_entity.dart';

class StudentAwardsStats {
  final int totalCount;
  final int thisMonthCount;
  final int typesEarnedCount;
  final Set<AwardType> earnedTypes;

  const StudentAwardsStats({
    required this.totalCount,
    required this.thisMonthCount,
    required this.typesEarnedCount,
    required this.earnedTypes,
  });
}

/// Personal receive-side stats from the student's `achievements` list.
StudentAwardsStats computeStudentAwardsStats(
  Iterable<AchievementEntity> achievements, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final startOfMonth = DateTime(current.year, current.month, 1);
  var thisMonthCount = 0;
  final earnedTypes = <AwardType>{};

  var totalCount = 0;
  for (final achievement in achievements) {
    totalCount++;
    if (!achievement.date.isBefore(startOfMonth)) {
      thisMonthCount++;
    }
    final type = achievement.type.awardType;
    if (type != null) earnedTypes.add(type);
  }

  return StudentAwardsStats(
    totalCount: totalCount,
    thisMonthCount: thisMonthCount,
    typesEarnedCount: earnedTypes.length,
    earnedTypes: earnedTypes,
  );
}
