import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/data/models/achievement_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';

void main() {
  group('AchievementModel.typeFromFirestoreKey', () {
    test('maps all 4 teacher award keys without collapsing to star', () {
      expect(
        AchievementModel.typeFromFirestoreKey(
          AwardType.completionBadge.firestoreKey,
        ),
        AchievementType.completionBadge,
      );
      expect(
        AchievementModel.typeFromFirestoreKey(
          AwardType.performanceStars.firestoreKey,
        ),
        AchievementType.performanceStars,
      );
      expect(
        AchievementModel.typeFromFirestoreKey(
          AwardType.perfectAttendance.firestoreKey,
        ),
        AchievementType.perfectAttendance,
      );
      expect(
        AchievementModel.typeFromFirestoreKey(
          AwardType.studentOfWeek.firestoreKey,
        ),
        AchievementType.studentOfWeek,
      );
    });

    test('keeps supervisor vocabulary', () {
      expect(
        AchievementModel.typeFromFirestoreKey('star'),
        AchievementType.star,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('badge'),
        AchievementType.badge,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('certificate'),
        AchievementType.certificate,
      );
    });

    test('maps new form type keys', () {
      expect(
        AchievementModel.typeFromFirestoreKey('attendance'),
        AchievementType.attendance,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('completion'),
        AchievementType.completion,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('performance'),
        AchievementType.performance,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('achievement'),
        AchievementType.achievement,
      );
      expect(
        AchievementModel.typeFromFirestoreKey('custom'),
        AchievementType.custom,
      );
    });

    test('unknown keys still fall back to star', () {
      expect(
        AchievementModel.typeFromFirestoreKey('unknown_type'),
        AchievementType.star,
      );
    });
  });
}
