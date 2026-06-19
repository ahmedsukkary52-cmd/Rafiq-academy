import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/achievement_entity.dart';
import '../entities/assignment_entity.dart';
import '../entities/halaqa_entity.dart';
import '../entities/recitation_record_entity.dart';
import '../entities/review_schedule_entity.dart';
import '../entities/student_profile_entity.dart';

abstract class StudentRepository {
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(String uid);

  Future<Either<Failure, List<ReviewScheduleEntity>>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  });

  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  );

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
}
