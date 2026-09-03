import 'package:equatable/equatable.dart';

import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/entities/supervisor_report_entity.dart';

abstract class SupervisorEvent extends Equatable {
  const SupervisorEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupervisedHalaqatEvent extends SupervisorEvent {
  final String supervisorId;

  const LoadSupervisedHalaqatEvent(this.supervisorId);

  @override
  List<Object?> get props => [supervisorId];
}

class LoadSupervisorDayBoardEvent extends SupervisorEvent {
  const LoadSupervisorDayBoardEvent();
}

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

class IssueAchievementEvent extends SupervisorEvent {
  final AchievementIssueEntity data;

  const IssueAchievementEvent(this.data);

  @override
  List<Object?> get props => [data];
}

class ResetIssueAchievementEvent extends SupervisorEvent {
  const ResetIssueAchievementEvent();
}

class SubmitSupervisorReportEvent extends SupervisorEvent {
  final SupervisorReportEntity report;

  const SubmitSupervisorReportEvent(this.report);

  @override
  List<Object?> get props => [report];
}

class ResetSubmitReportEvent extends SupervisorEvent {
  const ResetSubmitReportEvent();
}

/// Admit existing student into an assigned halaqa (Academy Admission).
class AdmitStudentToHalaqaEvent extends SupervisorEvent {
  final String supervisorId;
  final String halaqaId;
  final String studentId;

  const AdmitStudentToHalaqaEvent({
    required this.supervisorId,
    required this.halaqaId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [supervisorId, halaqaId, studentId];
}

class ResetAdmitStudentEvent extends SupervisorEvent {
  const ResetAdmitStudentEvent();
}

class TransferStudentBetweenHalaqatEvent extends SupervisorEvent {
  final String supervisorId;
  final String studentId;
  final String sourceHalaqaId;
  final String targetHalaqaId;

  const TransferStudentBetweenHalaqatEvent({
    required this.supervisorId,
    required this.studentId,
    required this.sourceHalaqaId,
    required this.targetHalaqaId,
  });

  @override
  List<Object?> get props => [
    supervisorId,
    studentId,
    sourceHalaqaId,
    targetHalaqaId,
  ];
}

class ResetTransferStudentEvent extends SupervisorEvent {
  const ResetTransferStudentEvent();
}

class ClearSupervisorSessionEvent extends SupervisorEvent {
  const ClearSupervisorSessionEvent();
}

class LoadSupervisedPaymentsEvent extends SupervisorEvent {
  final String supervisorId;
  final List<String> studentIds;

  const LoadSupervisedPaymentsEvent({
    required this.supervisorId,
    required this.studentIds,
  });

  @override
  List<Object?> get props => [supervisorId, studentIds];
}

class ReviewPaymentProofEvent extends SupervisorEvent {
  final PaymentReviewParams params;

  const ReviewPaymentProofEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class ResetReviewPaymentEvent extends SupervisorEvent {
  const ResetReviewPaymentEvent();
}
