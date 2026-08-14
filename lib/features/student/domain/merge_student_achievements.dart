import 'entities/achievement_entity.dart';

List<AchievementEntity> mergeStudentAchievements(
  Iterable<AchievementEntity> byStudentId,
  Iterable<AchievementEntity> byRecipientIds,
) {
  final byId = <String, AchievementEntity>{};
  for (final achievement in [...byStudentId, ...byRecipientIds]) {
    if (achievement.id.isEmpty) continue;
    byId[achievement.id] = achievement;
  }
  return byId.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
