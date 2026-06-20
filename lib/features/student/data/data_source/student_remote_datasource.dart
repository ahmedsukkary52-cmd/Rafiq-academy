import '../models/achievement_model.dart';
import '../models/assignment_model.dart';
import '../models/halaqa_model.dart';
import '../models/recitation_record_model.dart';
import '../models/review_schedule_model.dart';
import '../models/student_profile_model.dart';

abstract class StudentRemoteDatasource {
  Future<StudentProfileModel> getStudentProfile(String uid);

  Future<List<ReviewScheduleModel>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  });

  Future<List<RecitationRecordModel>> getRecitationRecords(String studentId);

  Future<List<AchievementModel>> getAchievements(String studentId);

  Future<AssignmentModel?> getLatestAssignment(String studentId);

  Future<HalaqaModel> getStudentHalaqa(String halaqaId);

  Stream<AssignmentModel?> watchLatestAssignment(String studentId);
}
