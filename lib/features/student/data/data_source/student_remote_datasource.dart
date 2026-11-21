import '../../../../shared/data/models/achievement_model.dart';
import '../../../../shared/data/models/assignment_model.dart';
import '../../../../shared/data/models/halaqa_model.dart';
import '../../../../shared/data/models/recitation_record_model.dart';
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

  /// Cursor page of achievements for [studentId] (dual query merge).
  ///
  /// [afterStudentAchievementId] / [afterRecipientsAchievementId] are the
  /// last raw doc ids from each query shape on the previous page.
  Future<
    ({
      List<AchievementModel> items,
      String? studentCursorId,
      String? recipientsCursorId,
      bool hasMoreStudent,
      bool hasMoreRecipients,
    })
  >
  getAchievementsPage({
    required String studentId,
    int limit = 20,
    String? afterStudentAchievementId,
    String? afterRecipientsAchievementId,
  });

  Future<AssignmentModel?> getLatestAssignment(String studentId);

  Future<HalaqaModel> getStudentHalaqa(String halaqaId);

  Stream<AssignmentModel?> watchLatestAssignment(String studentId);

  Future<void> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  });
}
