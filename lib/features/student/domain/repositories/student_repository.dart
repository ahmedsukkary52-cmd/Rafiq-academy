import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/achievement_entity.dart';
import '../../../../shared/domain/assignment_entity.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../../../shared/domain/recitation_record_entity.dart';
import '../../../../shared/domain/recitation_records_reader.dart';
import '../../../../shared/domain/student_achievements_reader.dart';
import '../entities/review_schedule_entity.dart';
import '../entities/student_profile_entity.dart';

/// One cursor page of a student's achievements (dual Firestore queries).
class StudentAchievementsPage extends Equatable {
  static const int defaultLimit = 20;

  final List<AchievementEntity> items;
  final String? studentCursorId;
  final String? recipientsCursorId;
  final bool hasMoreStudent;
  final bool hasMoreRecipients;

  const StudentAchievementsPage({
    required this.items,
    required this.studentCursorId,
    required this.recipientsCursorId,
    required this.hasMoreStudent,
    required this.hasMoreRecipients,
  });

  bool get hasMore => hasMoreStudent || hasMoreRecipients;

  @override
  List<Object?> get props => [
    items,
    studentCursorId,
    recipientsCursorId,
    hasMoreStudent,
    hasMoreRecipients,
  ];
}

abstract class StudentRepository
    implements RecitationRecordsReader, StudentAchievementsReader {
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(String uid);

  Future<Either<Failure, List<ReviewScheduleEntity>>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  });

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  );

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAchievements(
    String studentId,
  );

  /// Cursor page for student achievements UI (dual-query merge).
  Future<Either<Failure, StudentAchievementsPage>> getAchievementsPage({
    required String studentId,
    int limit = StudentAchievementsPage.defaultLimit,
    String? afterStudentAchievementId,
    String? afterRecipientsAchievementId,
  });

  Future<Either<Failure, AssignmentEntity?>> getLatestAssignment(
    String studentId,
  );

  Future<Either<Failure, HalaqaEntity>> getStudentHalaqa(String halaqaId);

  Stream<Either<Failure, AssignmentEntity?>> watchLatestAssignment(
    String studentId,
  );

  Future<Either<Failure, Unit>> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  });
}
