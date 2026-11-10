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
