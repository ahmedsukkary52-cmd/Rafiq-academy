import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../../../../shared/domain/academy_billing_entities.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AdminRemoteDatasource
// ══════════════════════════════════════════════════════════════════════════════

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

  /// C1 / WA-1 — Admin-provisioned Auth user via callable `adminProvisionUser`.
  Future<String> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    bool isActive = true,
  });

  /// C3 / WA-4 — Admin RW academySettings/paymentPublic.
  Future<PaymentPublicSettingsEntity> getPaymentPublicSettings();
  Future<void> updatePaymentPublicSettings({
    required String vodafoneCashDestination,
  });

  /// C3 / WA-4 — Admin-only pricingDefaults.
  Future<PricingDefaultsEntity> getPricingDefaults();
  Future<void> updatePricingDefaults({
    required int gracePeriodDays,
    required String defaultCurrency,
    required String defaultBillingPeriod,
  });

  /// C4 / WA-5 — Admin pricing rules.
  Future<List<PricingRuleEntity>> listPricingRules();
  Future<void> upsertPricingRule(PricingRuleEntity rule);

  /// C4 / WA-5 — invoke system invoice issuer via callable (Admin ops only).
  /// Amount comes from pricingRules server-side; never from the client.
  Future<String> generateInvoice({
    required String studentId,
    String? parentId,
    String? periodKey,
    String? pricingRuleId,
  });

  /// C2 / WA-3 — Admin reinstate paymentAccess (callable).
  Future<void> reinstatePaymentAccess({
    required String parentId,
    String? reason,
  });
}
