import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';
import 'package:rafiq_academy/features/student/domain/student_awards_stats.dart';

AchievementEntity _achievement({
  required String id,
  required AchievementType type,
  required DateTime date,
}) {
  return AchievementEntity(
    id: id,
    studentId: 's1',
    type: type,
    title: id,
    issuedBy: 'teacher-1',
    date: date,
  );
}

void main() {
  group('computeStudentAwardsStats', () {
    test('counts total, this month, and distinct teacher types', () {
      final now = DateTime(2026, 8, 14);
      final stats = computeStudentAwardsStats([
        _achievement(
          id: 'a1',
          type: AchievementType.studentOfWeek,
          date: DateTime(2026, 8, 2),
        ),
        _achievement(
          id: 'a2',
          type: AchievementType.performanceStars,
          date: DateTime(2026, 8, 10),
        ),
        _achievement(
          id: 'a3',
          type: AchievementType.performanceStars,
          date: DateTime(2026, 7, 20),
        ),
        _achievement(
          id: 'a4',
          type: AchievementType.badge,
          date: DateTime(2026, 8, 1),
        ),
      ], now: now);

      expect(stats.totalCount, 4);
      expect(stats.thisMonthCount, 3);
      expect(stats.typesEarnedCount, 2);
      expect(stats.earnedTypes, {
        AwardType.studentOfWeek,
        AwardType.performanceStars,
      });
    });

    test('empty list yields zeros', () {
      final stats = computeStudentAwardsStats(
        const [],
        now: DateTime(2026, 8, 14),
      );
      expect(stats.totalCount, 0);
      expect(stats.thisMonthCount, 0);
      expect(stats.typesEarnedCount, 0);
      expect(stats.earnedTypes, isEmpty);
    });
  });
}
