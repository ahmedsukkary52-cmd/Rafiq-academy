import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import 'achievement_entity.dart';

/// A student's achievements (by `studentId` and by `recipientStudentIds`),
/// merged and newest first, read directly from Firestore.
///
/// Firestore Rules allow these list queries only for the student themself and
/// staff. Parents are denied list queries and must keep using the parent
/// achievements callable (`getParentAchievements`).
abstract interface class StudentAchievementsReader {
  Future<Either<Failure, List<AchievementEntity>>> getAchievements(
    String studentId,
  );
}
