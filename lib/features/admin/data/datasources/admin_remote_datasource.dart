import '../../domain/admin_grant_reward_params.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';

abstract class AdminRemoteDatasource {
  Future<AcademyStatsEntity> getAcademyStats();
  Future<FinancialSummaryEntity> getFinancialSummary();

  Future<void> approveNewStudent({
    required String studentId,
    required String halaqaId,
  });

  Future<void> toggleAccountStatus({
    required String uid,
    required bool isActive,
  });

  Future<List<ComplaintEntity>> getComplaints();

  Future<void> respondToComplaint({
    required String complaintId,
    required String response,
  });

  Future<void> updateComplaint({
    required String complaintId,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeRole,
    String? response,
  });

  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  });

  Future<List<TeacherManagementEntity>> getAllTeachers();

  Future<void> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  });

  Future<void> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  });

  Future<TeacherActivityEntity> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  });

  Future<List<AdminHalaqaRosterEntity>> getAcademyStudentRoster();

  Future<List<RegistrationRequestEntity>> getRegistrationRequests();

  Future<void> rejectRegistrationRequest({required String studentId});

  Future<void> approveRegistrationRequest({
    required String studentId,
    required String halaqaId,
    String? teacherId,
    String? supervisorId,
  });

  Future<List<AdminHalaqaSummaryEntity>> getAllHalaqat();

  Future<List<AdminStaffSummaryEntity>> getAllSupervisors();

  Future<CommunicationSettingsEntity> getCommunicationSettings();

  Future<void> saveCommunicationSettings(CommunicationSettingsEntity settings);

  Future<void> grantReward(AdminGrantRewardParams params);

  Future<String> createHalaqa({
    required String name,
    required String teacherId,
    required String supervisorId,
    String meetingLink,
  });

  Future<String> ensureAdminInternalChat({required String adminUid});
}
