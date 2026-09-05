import 'package:equatable/equatable.dart';

import '../../domain/admin_grant_reward_params.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/repositories/admin_repository.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل إحصائيات الأكاديمية العامة
class LoadAcademyStatsEvent extends AdminEvent {
  const LoadAcademyStatsEvent();
}

/// تحميل الملخص المالي
class LoadFinancialSummaryEvent extends AdminEvent {
  const LoadFinancialSummaryEvent();
}

/// تحميل قائمة المدفوعات للمراجعة
class LoadPaymentsEvent extends AdminEvent {
  const LoadPaymentsEvent();
}

/// تحميل الإحصائيات والملخص المالي معاً (لوحة الإدارة الرئيسية)
class RefreshAdminDashboardEvent extends AdminEvent {
  const RefreshAdminDashboardEvent();
}

/// تحميل الشكاوى الواردة
class LoadComplaintsEvent extends AdminEvent {
  const LoadComplaintsEvent();
}

/// قبول طالب جديد وتوزيعه على حلقة
class ApproveNewStudentEvent extends AdminEvent {
  final String studentId;
  final String halaqaId;
  const ApproveNewStudentEvent({
    required this.studentId,
    required this.halaqaId,
  });

  @override
  List<Object?> get props => [studentId, halaqaId];
}

class ResetApproveStudentEvent extends AdminEvent {
  const ResetApproveStudentEvent();
}

/// تفعيل أو تعطيل حساب مستخدم
class ToggleAccountStatusEvent extends AdminEvent {
  final String uid;
  final bool isActive;

  const ToggleAccountStatusEvent({required this.uid, required this.isActive});

  @override
  List<Object?> get props => [uid, isActive];
}

class ResetToggleAccountEvent extends AdminEvent {
  const ResetToggleAccountEvent();
}

/// الرد على شكوى
class RespondToComplaintEvent extends AdminEvent {
  final String complaintId;
  final String response;
  const RespondToComplaintEvent({
    required this.complaintId,
    required this.response,
  });

  @override
  List<Object?> get props => [complaintId, response];
}

class ResetRespondComplaintEvent extends AdminEvent {
  const ResetRespondComplaintEvent();
}

/// إرسال إشعار موحّد لفئة معينة أو الكل
class SendBroadcastNotificationEvent extends AdminEvent {
  final String title;
  final String body;
  final String targetRole;
  const SendBroadcastNotificationEvent({
    required this.title,
    required this.body,
    required this.targetRole,
  });

  @override
  List<Object?> get props => [title, body, targetRole];
}

class ResetBroadcastEvent extends AdminEvent {
  const ResetBroadcastEvent();
}

/// تحميل قائمة كل المعلمين مع بيانات النصاب والتقييم
class LoadAllTeachersEvent extends AdminEvent {
  const LoadAllTeachersEvent();
}

/// تحديث تقييم أداء معلم
class UpdateTeacherPerformanceEvent extends AdminEvent {
  final String teacherId;
  final double rating;

  const UpdateTeacherPerformanceEvent({
    required this.teacherId,
    required this.rating,
  });

  @override
  List<Object?> get props => [teacherId, rating];
}

class ResetUpdateTeacherPerformanceEvent extends AdminEvent {
  const ResetUpdateTeacherPerformanceEvent();
}

/// تحديد نصاب الحصص الأسبوعي لمعلم
class UpdateTeacherQuotaEvent extends AdminEvent {
  final String teacherId;
  final int weeklyQuota;

  const UpdateTeacherQuotaEvent({
    required this.teacherId,
    required this.weeklyQuota,
  });

  @override
  List<Object?> get props => [teacherId, weeklyQuota];
}

class ResetUpdateTeacherQuotaEvent extends AdminEvent {
  const ResetUpdateTeacherQuotaEvent();
}

/// تحميل سجل نشاط معلم (الأيام اللي سجّل فيها حضور) خلال فترة معيّنة
class LoadTeacherActivityLogEvent extends AdminEvent {
  final String teacherId;
  final DateTime from;
  final DateTime to;

  const LoadTeacherActivityLogEvent({
    required this.teacherId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [teacherId, from, to];
}

/// Clear projection on logout so the next identity cannot inherit state (H1).
class ClearAdminSessionEvent extends AdminEvent {
  const ClearAdminSessionEvent();
}

class LoadStudentRosterEvent extends AdminEvent {
  const LoadStudentRosterEvent();
}

class LoadRegistrationRequestsEvent extends AdminEvent {
  const LoadRegistrationRequestsEvent();
}

class LoadAdminDirectoryEvent extends AdminEvent {
  const LoadAdminDirectoryEvent();
}

class RejectRegistrationRequestEvent extends AdminEvent {
  final String studentId;
  const RejectRegistrationRequestEvent({required this.studentId});

  @override
  List<Object?> get props => [studentId];
}

class ApproveRegistrationRequestEvent extends AdminEvent {
  final String studentId;
  final String halaqaId;
  final String? teacherId;
  final String? supervisorId;

  const ApproveRegistrationRequestEvent({
    required this.studentId,
    required this.halaqaId,
    this.teacherId,
    this.supervisorId,
  });

  @override
  List<Object?> get props => [studentId, halaqaId, teacherId, supervisorId];
}

class ResetRegistrationActionEvent extends AdminEvent {
  const ResetRegistrationActionEvent();
}

class UpdateComplaintEvent extends AdminEvent {
  final String complaintId;
  final String? status;
  final String? priority;
  final String? assigneeId;
  final String? assigneeRole;
  final String? response;

  const UpdateComplaintEvent({
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

class ResetUpdateComplaintEvent extends AdminEvent {
  const ResetUpdateComplaintEvent();
}

class LoadCommunicationSettingsEvent extends AdminEvent {
  const LoadCommunicationSettingsEvent();
}

class SaveCommunicationSettingsEvent extends AdminEvent {
  final CommunicationSettingsEntity settings;
  const SaveCommunicationSettingsEvent({required this.settings});

  @override
  List<Object?> get props => [settings];
}

class ResetCommunicationSettingsEvent extends AdminEvent {
  const ResetCommunicationSettingsEvent();
}

class GrantAdminRewardEvent extends AdminEvent {
  final AdminGrantRewardParams params;
  const GrantAdminRewardEvent({required this.params});

  @override
  List<Object?> get props => [params];
}

class ResetGrantRewardEvent extends AdminEvent {
  const ResetGrantRewardEvent();
}

class CreateHalaqaEvent extends AdminEvent {
  final CreateHalaqaParams params;
  const CreateHalaqaEvent({required this.params});

  @override
  List<Object?> get props => [params];
}

class ResetCreateHalaqaEvent extends AdminEvent {
  const ResetCreateHalaqaEvent();
}

class EnsureAdminInternalChatEvent extends AdminEvent {
  final String adminUid;
  const EnsureAdminInternalChatEvent({required this.adminUid});

  @override
  List<Object?> get props => [adminUid];
}
