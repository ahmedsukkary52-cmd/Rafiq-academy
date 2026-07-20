
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AdminRemoteDatasource
// ══════════════════════════════════════════════════════════════════════════════

abstract class AdminRemoteDatasource {
  Future<AcademyStatsEntity> getAcademyStats();
  Future<FinancialSummaryEntity> getFinancialSummary();

  Future<void> approveNewStudent(
      {required String studentId, required String halaqaId});

  Future<void> toggleAccountStatus(
      {required String uid, required bool isActive});
  Future<List<ComplaintEntity>> getComplaints();

  Future<void> respondToComplaint(
      {required String complaintId, required String response});
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
}
