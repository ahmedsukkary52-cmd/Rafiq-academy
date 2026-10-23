import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../admin_grant_reward_params.dart';
import '../entities/academy_stats_entity.dart';
import '../entities/admin_directory_entity.dart';
import '../entities/admin_halaqa_roster_entity.dart';
import '../entities/communication_settings_entity.dart';
import '../entities/complaint_entity.dart';
import '../entities/admin_payment_entity.dart';
import '../entities/financial_summary_entity.dart';
import '../entities/registration_request_entity.dart';
import '../entities/teacher_activity_entity.dart';
import '../entities/teacher_management_entity.dart';

abstract class AdminRepository {
  Future<Either<Failure, AcademyStatsEntity>> getAcademyStats();
  Future<Either<Failure, FinancialSummaryEntity>> getFinancialSummary();
  Future<Either<Failure, List<AdminPaymentEntity>>> getPayments();

  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  });

  Future<Either<Failure, Unit>> toggleAccountStatus({
    required String uid,
    required bool isActive,
  });

  Future<Either<Failure, List<ComplaintEntity>>> getComplaints();

  Future<Either<Failure, Unit>> respondToComplaint({
    required String complaintId,
    required String response,
  });

  Future<Either<Failure, Unit>> updateComplaint({
    required String complaintId,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeRole,
    String? response,
  });

  Future<Either<Failure, Unit>> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  });

  Future<Either<Failure, List<TeacherManagementEntity>>> getAllTeachers();

  Future<Either<Failure, Unit>> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  });

  Future<Either<Failure, Unit>> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  });

  Future<Either<Failure, TeacherActivityEntity>> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  });

  /// C1 — Admin provisions Auth + users + profile via Cloud Function.
  Future<Either<Failure, String>> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    bool isActive,
  });

  Future<Either<Failure, PaymentPublicSettingsEntity>>
  getPaymentPublicSettings();

  Future<Either<Failure, Unit>> updatePaymentPublicSettings({
    String? vodafoneCashDestination,
    String? instapayDestination,
  });

  Future<Either<Failure, PricingDefaultsEntity>> getPricingDefaults();

  Future<Either<Failure, Unit>> updatePricingDefaults({
    required int gracePeriodDays,
    required String defaultCurrency,
    required String defaultBillingPeriod,
  });

  Future<Either<Failure, List<PricingRuleEntity>>> listPricingRules();

  Future<Either<Failure, Unit>> upsertPricingRule(PricingRuleEntity rule);

  Future<Either<Failure, String>> generateInvoice({
    required String studentId,
    String? parentId,
    String? periodKey,
    String? pricingRuleId,
  });

  Future<Either<Failure, Unit>> reinstatePaymentAccess({
    required String parentId,
    String? reason,
  });

  Future<Either<Failure, List<AdminHalaqaRosterEntity>>>
  getAcademyStudentRoster();

  Future<Either<Failure, List<RegistrationRequestEntity>>>
  getRegistrationRequests();

  Future<Either<Failure, Unit>> rejectRegistrationRequest({
    required String studentId,
  });

  Future<Either<Failure, Unit>> approveRegistrationRequest({
    required String studentId,
    required String halaqaId,
    String? teacherId,
    String? supervisorId,
  });

  Future<Either<Failure, List<AdminHalaqaSummaryEntity>>> getAllHalaqat();

  Future<Either<Failure, List<AdminStaffSummaryEntity>>> getAllSupervisors();

  Future<Either<Failure, CommunicationSettingsEntity>>
  getCommunicationSettings();

  Future<Either<Failure, Unit>> saveCommunicationSettings(
    CommunicationSettingsEntity settings,
  );

  Future<Either<Failure, Unit>> grantReward(AdminGrantRewardParams params);

  Future<Either<Failure, String>> ensureAdminInternalChat({
    required String adminUid,
  });
}

class ApproveStudentParams extends Equatable {
  final String studentId;
  final String halaqaId;

  const ApproveStudentParams({required this.studentId, required this.halaqaId});

  @override
  List<Object?> get props => [studentId, halaqaId];
}

class ToggleAccountParams extends Equatable {
  final String uid;
  final bool isActive;

  const ToggleAccountParams({required this.uid, required this.isActive});

  @override
  List<Object?> get props => [uid, isActive];
}

class RespondComplaintParams extends Equatable {
  final String complaintId;
  final String response;

  const RespondComplaintParams({
    required this.complaintId,
    required this.response,
  });

  @override
  List<Object?> get props => [complaintId, response];
}

class UpdateComplaintParams extends Equatable {
  final String complaintId;
  final String? status;
  final String? priority;
  final String? assigneeId;
  final String? assigneeRole;
  final String? response;

  const UpdateComplaintParams({
    required this.complaintId,
    this.status,
    this.priority,
    this.assigneeId,
    this.assigneeRole,
    this.response,
  });

  @override
  List<Object?> get props => [
    complaintId,
    status,
    priority,
    assigneeId,
    assigneeRole,
    response,
  ];
}

class BroadcastParams extends Equatable {
  final String title;
  final String body;
  final String targetRole;

  const BroadcastParams({
    required this.title,
    required this.body,
    required this.targetRole,
  });

  @override
  List<Object?> get props => [title, body, targetRole];
}

class UpdateTeacherPerformanceParams extends Equatable {
  final String teacherId;
  final double rating;

  const UpdateTeacherPerformanceParams({
    required this.teacherId,
    required this.rating,
  });

  @override
  List<Object?> get props => [teacherId, rating];
}

class UpdateTeacherQuotaParams extends Equatable {
  final String teacherId;
  final int weeklyQuota;

  const UpdateTeacherQuotaParams({
    required this.teacherId,
    required this.weeklyQuota,
  });

  @override
  List<Object?> get props => [teacherId, weeklyQuota];
}

class TeacherActivityParams extends Equatable {
  final String teacherId;
  final DateTime from;
  final DateTime to;

  const TeacherActivityParams({
    required this.teacherId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [teacherId, from, to];
}

class ProvisionUserParams extends Equatable {
  final String email;
  final String password;
  final String name;
  final String role;
  final bool isActive;

  const ProvisionUserParams({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [email, password, name, role, isActive];
}

class ApproveRegistrationParams extends Equatable {
  final String studentId;
  final String halaqaId;
  final String? teacherId;
  final String? supervisorId;

  const ApproveRegistrationParams({
    required this.studentId,
    required this.halaqaId,
    this.teacherId,
    this.supervisorId,
  });

  @override
  List<Object?> get props => [studentId, halaqaId, teacherId, supervisorId];
}

class RejectRegistrationParams extends Equatable {
  final String studentId;

  const RejectRegistrationParams({required this.studentId});

  @override
  List<Object?> get props => [studentId];
}

class EnsureAdminInternalChatParams extends Equatable {
  final String adminUid;

  const EnsureAdminInternalChatParams({required this.adminUid});

  @override
  List<Object?> get props => [adminUid];
}
