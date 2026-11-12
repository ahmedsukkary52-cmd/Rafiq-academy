import '../../domain/admin_grant_reward_params.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/admin_payment_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../../../../shared/domain/academy_billing_entities.dart';

abstract class AdminRemoteDatasource {
  Future<AcademyStatsEntity> getAcademyStats();
  Future<FinancialSummaryEntity> getFinancialSummary();
  Future<List<AdminPaymentEntity>> getPayments();

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

  /// The same [requestId] never creates a second notification.
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
    String? requestId,
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
    bool isActive = true,
  });

  /// C3 / WA-4 — Admin RW academySettings/paymentPublic.
  Future<PaymentPublicSettingsEntity> getPaymentPublicSettings();

  /// Writes only the provided fields; an omitted method is left untouched.
  Future<void> updatePaymentPublicSettings({
    String? vodafoneCashDestination,
    String? instapayDestination,
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

  Future<String> ensureAdminInternalChat({required String adminUid});
}
