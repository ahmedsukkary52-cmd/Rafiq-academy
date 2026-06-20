import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';

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

  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  });
}
