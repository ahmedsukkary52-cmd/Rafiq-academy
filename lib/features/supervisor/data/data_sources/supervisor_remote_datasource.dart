import '../../../../shared/data/absence_request_model.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/supervisor_report_entity.dart';

abstract class SupervisorRemoteDatasource {
  Future<List<HalaqaModel>> getSupervisedHalaqat(String supervisorId);

  Future<void> issueAchievement(AchievementIssueEntity data);

  Future<void> submitReport(SupervisorReportEntity report);

  /// Admit / add existing student to [halaqaId] via Academy Admission Workflow.
  /// Requires [halaqaId] to be supervised by [supervisorId].
  Future<void> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  });

  /// Immediate move between supervised halaqat (Dual-Halaqa transfer).
  Future<void> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  });

  /// `users/{id}.name` for the given ids (chunked `whereIn`).
  Future<Map<String, String>> getUserDisplayNames(List<String> userIds);

  /// Absence request docs for [halaqaIds] on [date] (all statuses — projection).
  Future<List<AbsenceRequestModel>> getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  });
}
