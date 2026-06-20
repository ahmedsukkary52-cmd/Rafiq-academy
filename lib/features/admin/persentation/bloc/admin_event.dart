import 'package:equatable/equatable.dart';

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
