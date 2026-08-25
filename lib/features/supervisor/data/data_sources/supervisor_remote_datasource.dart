import '../../../../shared/data/absence_request_model.dart';
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

  /// `users/{id}.name` for the given ids (chunked `whereIn`).
  Future<Map<String, String>> getUserDisplayNames(List<String> userIds);

  /// Absence request docs for [halaqaIds] on [date] (all statuses — projection).
  Future<List<AbsenceRequestModel>> getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  });
}
