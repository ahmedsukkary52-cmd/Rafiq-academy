import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AdminState extends Equatable {
  // ── إحصائيات الأكاديمية ───────────────────────────────────────────────
  final SectionStatus statsStatus;
  final AcademyStatsEntity? stats;
  final String? statsError;

  // ── الملخص المالي ─────────────────────────────────────────────────────
  final SectionStatus financialStatus;
  final FinancialSummaryEntity? financialSummary;
  final String? financialError;

  // ── الشكاوى ───────────────────────────────────────────────────────────
  final SectionStatus complaintsStatus;
  final List<ComplaintEntity> complaints;
  final String? complaintsError;

  // ── عمليات الإدارة (قبول طالب، تفعيل حساب، رد على شكوى، بث إشعار) ──────
  final SubmissionStatus approveStudentStatus;
  final String? approveStudentError;

  final SubmissionStatus toggleAccountStatus;
  final String? toggleAccountError;

  final SubmissionStatus respondComplaintStatus;
  final String? respondComplaintError;

  final SubmissionStatus broadcastStatus;
  final String? broadcastError;

  // ── إدارة شؤون المعلمين ───────────────────────────────────────────────
  final SectionStatus teachersStatus;
  final List<TeacherManagementEntity> teachers;
  final String? teachersError;

  final SubmissionStatus updatePerformanceStatus;
  final String? updatePerformanceError;

  final SubmissionStatus updateQuotaStatus;
  final String? updateQuotaError;

  final SectionStatus teacherActivityStatus;
  final TeacherActivityEntity? teacherActivity;
  final String? teacherActivityError;

  final SectionStatus rosterStatus;
  final List<AdminHalaqaRosterEntity> studentRoster;
  final String? rosterError;

  final SectionStatus registrationStatus;
  final List<RegistrationRequestEntity> registrationRequests;
  final String? registrationError;
  final SubmissionStatus registrationActionStatus;
  final String? registrationActionError;

  final SectionStatus directoryStatus;
  final List<AdminHalaqaSummaryEntity> halaqatDirectory;
  final List<AdminStaffSummaryEntity> supervisorsDirectory;
  final String? directoryError;

  final SubmissionStatus updateComplaintStatus;
  final String? updateComplaintError;

  final SectionStatus communicationSettingsStatus;
  final CommunicationSettingsEntity? communicationSettings;
  final String? communicationSettingsError;
  final SubmissionStatus saveCommunicationSettingsStatus;
  final String? saveCommunicationSettingsError;

  final SubmissionStatus grantRewardStatus;
  final String? grantRewardError;

  final SubmissionStatus createHalaqaStatus;
  final String? createHalaqaError;
  final String? lastCreatedHalaqaId;

  final SubmissionStatus adminInternalChatStatus;
  final String? adminInternalChatId;
  final String? adminInternalChatError;

  const AdminState({
    this.statsStatus = SectionStatus.initial,
    this.stats,
    this.statsError,
    this.financialStatus = SectionStatus.initial,
    this.financialSummary,
    this.financialError,
    this.complaintsStatus = SectionStatus.initial,
    this.complaints = const [],
    this.complaintsError,
    this.approveStudentStatus = SubmissionStatus.idle,
    this.approveStudentError,
    this.toggleAccountStatus = SubmissionStatus.idle,
    this.toggleAccountError,
    this.respondComplaintStatus = SubmissionStatus.idle,
    this.respondComplaintError,
    this.broadcastStatus = SubmissionStatus.idle,
    this.broadcastError,
    this.teachersStatus = SectionStatus.initial,
    this.teachers = const [],
    this.teachersError,
    this.updatePerformanceStatus = SubmissionStatus.idle,
    this.updatePerformanceError,
    this.updateQuotaStatus = SubmissionStatus.idle,
    this.updateQuotaError,
    this.teacherActivityStatus = SectionStatus.initial,
    this.teacherActivity,
    this.teacherActivityError,
    this.rosterStatus = SectionStatus.initial,
    this.studentRoster = const [],
    this.rosterError,
    this.registrationStatus = SectionStatus.initial,
    this.registrationRequests = const [],
    this.registrationError,
    this.registrationActionStatus = SubmissionStatus.idle,
    this.registrationActionError,
    this.directoryStatus = SectionStatus.initial,
    this.halaqatDirectory = const [],
    this.supervisorsDirectory = const [],
    this.directoryError,
    this.updateComplaintStatus = SubmissionStatus.idle,
    this.updateComplaintError,
    this.communicationSettingsStatus = SectionStatus.initial,
    this.communicationSettings,
    this.communicationSettingsError,
    this.saveCommunicationSettingsStatus = SubmissionStatus.idle,
    this.saveCommunicationSettingsError,
    this.grantRewardStatus = SubmissionStatus.idle,
    this.grantRewardError,
    this.createHalaqaStatus = SubmissionStatus.idle,
    this.createHalaqaError,
    this.lastCreatedHalaqaId,
    this.adminInternalChatStatus = SubmissionStatus.idle,
    this.adminInternalChatId,
    this.adminInternalChatError,
  });

  factory AdminState.initial() => const AdminState();

  AdminState copyWith({
    SectionStatus? statsStatus,
    Object? stats = _unset,
    Object? statsError = _unset,
    SectionStatus? financialStatus,
    Object? financialSummary = _unset,
    Object? financialError = _unset,
    SectionStatus? complaintsStatus,
    List<ComplaintEntity>? complaints,
    Object? complaintsError = _unset,
    SubmissionStatus? approveStudentStatus,
    Object? approveStudentError = _unset,
    SubmissionStatus? toggleAccountStatus,
    Object? toggleAccountError = _unset,
    SubmissionStatus? respondComplaintStatus,
    Object? respondComplaintError = _unset,
    SubmissionStatus? broadcastStatus,
    Object? broadcastError = _unset,
    SectionStatus? teachersStatus,
    List<TeacherManagementEntity>? teachers,
    Object? teachersError = _unset,
    SubmissionStatus? updatePerformanceStatus,
    Object? updatePerformanceError = _unset,
    SubmissionStatus? updateQuotaStatus,
    Object? updateQuotaError = _unset,
    SectionStatus? teacherActivityStatus,
    Object? teacherActivity = _unset,
    Object? teacherActivityError = _unset,
    SectionStatus? rosterStatus,
    List<AdminHalaqaRosterEntity>? studentRoster,
    Object? rosterError = _unset,
    SectionStatus? registrationStatus,
    List<RegistrationRequestEntity>? registrationRequests,
    Object? registrationError = _unset,
    SubmissionStatus? registrationActionStatus,
    Object? registrationActionError = _unset,
    SectionStatus? directoryStatus,
    List<AdminHalaqaSummaryEntity>? halaqatDirectory,
    List<AdminStaffSummaryEntity>? supervisorsDirectory,
    Object? directoryError = _unset,
    SubmissionStatus? updateComplaintStatus,
    Object? updateComplaintError = _unset,
    SectionStatus? communicationSettingsStatus,
    Object? communicationSettings = _unset,
    Object? communicationSettingsError = _unset,
    SubmissionStatus? saveCommunicationSettingsStatus,
    Object? saveCommunicationSettingsError = _unset,
    SubmissionStatus? grantRewardStatus,
    Object? grantRewardError = _unset,
    SubmissionStatus? createHalaqaStatus,
    Object? createHalaqaError = _unset,
    Object? lastCreatedHalaqaId = _unset,
    SubmissionStatus? adminInternalChatStatus,
    Object? adminInternalChatId = _unset,
    Object? adminInternalChatError = _unset,
  }) {
    return AdminState(
      statsStatus: statsStatus ?? this.statsStatus,
      stats: identical(stats, _unset)
          ? this.stats
          : stats as AcademyStatsEntity?,
      statsError: identical(statsError, _unset)
          ? this.statsError
          : statsError as String?,
      financialStatus: financialStatus ?? this.financialStatus,
      financialSummary: identical(financialSummary, _unset)
          ? this.financialSummary
          : financialSummary as FinancialSummaryEntity?,
      financialError: identical(financialError, _unset)
          ? this.financialError
          : financialError as String?,
      complaintsStatus: complaintsStatus ?? this.complaintsStatus,
      complaints: complaints ?? this.complaints,
      complaintsError: identical(complaintsError, _unset)
          ? this.complaintsError
          : complaintsError as String?,
      approveStudentStatus: approveStudentStatus ?? this.approveStudentStatus,
      approveStudentError: identical(approveStudentError, _unset)
          ? this.approveStudentError
          : approveStudentError as String?,
      toggleAccountStatus: toggleAccountStatus ?? this.toggleAccountStatus,
      toggleAccountError: identical(toggleAccountError, _unset)
          ? this.toggleAccountError
          : toggleAccountError as String?,
      respondComplaintStatus:
          respondComplaintStatus ?? this.respondComplaintStatus,
      respondComplaintError: identical(respondComplaintError, _unset)
          ? this.respondComplaintError
          : respondComplaintError as String?,
      broadcastStatus: broadcastStatus ?? this.broadcastStatus,
      broadcastError: identical(broadcastError, _unset)
          ? this.broadcastError
          : broadcastError as String?,
      teachersStatus: teachersStatus ?? this.teachersStatus,
      teachers: teachers ?? this.teachers,
      teachersError: identical(teachersError, _unset)
          ? this.teachersError
          : teachersError as String?,
      updatePerformanceStatus:
          updatePerformanceStatus ?? this.updatePerformanceStatus,
      updatePerformanceError: identical(updatePerformanceError, _unset)
          ? this.updatePerformanceError
          : updatePerformanceError as String?,
      updateQuotaStatus: updateQuotaStatus ?? this.updateQuotaStatus,
      updateQuotaError: identical(updateQuotaError, _unset)
          ? this.updateQuotaError
          : updateQuotaError as String?,
      teacherActivityStatus:
          teacherActivityStatus ?? this.teacherActivityStatus,
      teacherActivity: identical(teacherActivity, _unset)
          ? this.teacherActivity
          : teacherActivity as TeacherActivityEntity?,
      teacherActivityError: identical(teacherActivityError, _unset)
          ? this.teacherActivityError
          : teacherActivityError as String?,
      rosterStatus: rosterStatus ?? this.rosterStatus,
      studentRoster: studentRoster ?? this.studentRoster,
      rosterError: identical(rosterError, _unset)
          ? this.rosterError
          : rosterError as String?,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      registrationRequests: registrationRequests ?? this.registrationRequests,
      registrationError: identical(registrationError, _unset)
          ? this.registrationError
          : registrationError as String?,
      registrationActionStatus:
          registrationActionStatus ?? this.registrationActionStatus,
      registrationActionError: identical(registrationActionError, _unset)
          ? this.registrationActionError
          : registrationActionError as String?,
      directoryStatus: directoryStatus ?? this.directoryStatus,
      halaqatDirectory: halaqatDirectory ?? this.halaqatDirectory,
      supervisorsDirectory: supervisorsDirectory ?? this.supervisorsDirectory,
      directoryError: identical(directoryError, _unset)
          ? this.directoryError
          : directoryError as String?,
      updateComplaintStatus:
          updateComplaintStatus ?? this.updateComplaintStatus,
      updateComplaintError: identical(updateComplaintError, _unset)
          ? this.updateComplaintError
          : updateComplaintError as String?,
      communicationSettingsStatus:
          communicationSettingsStatus ?? this.communicationSettingsStatus,
      communicationSettings: identical(communicationSettings, _unset)
          ? this.communicationSettings
          : communicationSettings as CommunicationSettingsEntity?,
      communicationSettingsError: identical(communicationSettingsError, _unset)
          ? this.communicationSettingsError
          : communicationSettingsError as String?,
      saveCommunicationSettingsStatus:
          saveCommunicationSettingsStatus ??
          this.saveCommunicationSettingsStatus,
      saveCommunicationSettingsError:
          identical(saveCommunicationSettingsError, _unset)
          ? this.saveCommunicationSettingsError
          : saveCommunicationSettingsError as String?,
      grantRewardStatus: grantRewardStatus ?? this.grantRewardStatus,
      grantRewardError: identical(grantRewardError, _unset)
          ? this.grantRewardError
          : grantRewardError as String?,
      createHalaqaStatus: createHalaqaStatus ?? this.createHalaqaStatus,
      createHalaqaError: identical(createHalaqaError, _unset)
          ? this.createHalaqaError
          : createHalaqaError as String?,
      lastCreatedHalaqaId: identical(lastCreatedHalaqaId, _unset)
          ? this.lastCreatedHalaqaId
          : lastCreatedHalaqaId as String?,
      adminInternalChatStatus:
          adminInternalChatStatus ?? this.adminInternalChatStatus,
      adminInternalChatId: identical(adminInternalChatId, _unset)
          ? this.adminInternalChatId
          : adminInternalChatId as String?,
      adminInternalChatError: identical(adminInternalChatError, _unset)
          ? this.adminInternalChatError
          : adminInternalChatError as String?,
    );
  }

  @override
  List<Object?> get props => [
    statsStatus,
    stats,
    statsError,
    financialStatus,
    financialSummary,
    financialError,
    complaintsStatus,
    complaints,
    complaintsError,
    approveStudentStatus,
    approveStudentError,
    toggleAccountStatus,
    toggleAccountError,
    respondComplaintStatus,
    respondComplaintError,
    broadcastStatus,
    broadcastError,
    teachersStatus,
    teachers,
    teachersError,
    updatePerformanceStatus,
    updatePerformanceError,
    updateQuotaStatus,
    updateQuotaError,
    teacherActivityStatus,
    teacherActivity,
    teacherActivityError,
    rosterStatus,
    studentRoster,
    rosterError,
    registrationStatus,
    registrationRequests,
    registrationError,
    registrationActionStatus,
    registrationActionError,
    directoryStatus,
    halaqatDirectory,
    supervisorsDirectory,
    directoryError,
    updateComplaintStatus,
    updateComplaintError,
    communicationSettingsStatus,
    communicationSettings,
    communicationSettingsError,
    saveCommunicationSettingsStatus,
    saveCommunicationSettingsError,
    grantRewardStatus,
    grantRewardError,
    createHalaqaStatus,
    createHalaqaError,
    lastCreatedHalaqaId,
    adminInternalChatStatus,
    adminInternalChatId,
    adminInternalChatError,
  ];
}
