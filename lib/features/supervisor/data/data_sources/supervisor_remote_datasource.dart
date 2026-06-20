import '../../../student/data/models/halaqa_model.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/supervisor_report_entity.dart';

abstract class SupervisorRemoteDatasource {
  Future<List<HalaqaModel>> getSupervisedHalaqat(String supervisorId);

  Future<void> issueAchievement(AchievementIssueEntity data);

  Future<void> submitReport(SupervisorReportEntity report);

  Future<void> registerNewStudent({
    required String halaqaId,
    required String studentId,
  });
}
