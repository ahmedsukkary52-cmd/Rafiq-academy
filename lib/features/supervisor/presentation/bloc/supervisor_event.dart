import 'package:equatable/equatable.dart';

import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/supervisor_report_entity.dart';

abstract class SupervisorEvent extends Equatable {
  const SupervisorEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل الحلقات اللي تحت إشراف المشرف
class LoadSupervisedHalaqatEvent extends SupervisorEvent {
  final String supervisorId;

  const LoadSupervisedHalaqatEvent(this.supervisorId);

  @override
  List<Object?> get props => [supervisorId];
}

/// Derive today's oversight board from already-loaded supervised halaqat (W6).
class LoadSupervisorDayBoardEvent extends SupervisorEvent {
  const LoadSupervisorDayBoardEvent();
}

/// Read-only استئذان projection for today (W7 Slice 3).
class LoadSupervisedAbsenceRequestsEvent extends SupervisorEvent {
  final String supervisorId;
  final DateTime date;

  const LoadSupervisedAbsenceRequestsEvent({
    required this.supervisorId,
    required this.date,
  });

  @override
  List<Object?> get props => [supervisorId, date];
}

/// إرسال تشجيع/وسام لطالب متميز
class IssueAchievementEvent extends SupervisorEvent {
  final AchievementIssueEntity data;

  const IssueAchievementEvent(this.data);

  @override
  List<Object?> get props => [data];
}

class ResetIssueAchievementEvent extends SupervisorEvent {
  const ResetIssueAchievementEvent();
}

/// رفع تقرير دوري أو بلاغ للإدارة
class SubmitSupervisorReportEvent extends SupervisorEvent {
  final SupervisorReportEntity report;

  const SubmitSupervisorReportEvent(this.report);

  @override
  List<Object?> get props => [report];
}

class ResetSubmitReportEvent extends SupervisorEvent {
  const ResetSubmitReportEvent();
}

/// تسجيل ملتحق جديد في حلقة
class RegisterNewStudentEvent extends SupervisorEvent {
  final String halaqaId;
  final String studentId;

  const RegisterNewStudentEvent({
    required this.halaqaId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [halaqaId, studentId];
}

class ResetRegisterStudentEvent extends SupervisorEvent {
  const ResetRegisterStudentEvent();
}

/// Clear projection on logout so the next identity cannot inherit state (H1).
class ClearSupervisorSessionEvent extends SupervisorEvent {
  const ClearSupervisorSessionEvent();
}
