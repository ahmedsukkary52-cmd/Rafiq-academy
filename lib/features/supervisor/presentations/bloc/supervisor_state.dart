import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/entities/halaqa_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class SupervisorState extends Equatable {
  // ── الحلقات تحت الإشراف ───────────────────────────────────────────────
  final SectionStatus halaqatStatus;
  final List<HalaqaEntity> halaqat;
  final String? halaqatError;

  // ── إرسال تشجيع/وسام ──────────────────────────────────────────────────
  final SubmissionStatus issueAchievementStatus;
  final String? issueAchievementError;

  // ── رفع تقرير ─────────────────────────────────────────────────────────
  final SubmissionStatus submitReportStatus;
  final String? submitReportError;

  // ── تسجيل ملتحق جديد ──────────────────────────────────────────────────
  final SubmissionStatus registerStudentStatus;
  final String? registerStudentError;

  const SupervisorState({
    this.halaqatStatus = SectionStatus.initial,
    this.halaqat = const [],
    this.halaqatError,
    this.issueAchievementStatus = SubmissionStatus.idle,
    this.issueAchievementError,
    this.submitReportStatus = SubmissionStatus.idle,
    this.submitReportError,
    this.registerStudentStatus = SubmissionStatus.idle,
    this.registerStudentError,
  });

  factory SupervisorState.initial() => const SupervisorState();

  SupervisorState copyWith({
    SectionStatus? halaqatStatus,
    List<HalaqaEntity>? halaqat,
    Object? halaqatError = _unset,
    SubmissionStatus? issueAchievementStatus,
    Object? issueAchievementError = _unset,
    SubmissionStatus? submitReportStatus,
    Object? submitReportError = _unset,
    SubmissionStatus? registerStudentStatus,
    Object? registerStudentError = _unset,
  }) {
    return SupervisorState(
      halaqatStatus: halaqatStatus ?? this.halaqatStatus,
      halaqat: halaqat ?? this.halaqat,
      halaqatError: identical(halaqatError, _unset)
          ? this.halaqatError
          : halaqatError as String?,
      issueAchievementStatus:
          issueAchievementStatus ?? this.issueAchievementStatus,
      issueAchievementError: identical(issueAchievementError, _unset)
          ? this.issueAchievementError
          : issueAchievementError as String?,
      submitReportStatus: submitReportStatus ?? this.submitReportStatus,
      submitReportError: identical(submitReportError, _unset)
          ? this.submitReportError
          : submitReportError as String?,
      registerStudentStatus:
          registerStudentStatus ?? this.registerStudentStatus,
      registerStudentError: identical(registerStudentError, _unset)
          ? this.registerStudentError
          : registerStudentError as String?,
    );
  }

  @override
  List<Object?> get props => [
    halaqatStatus,
    halaqat,
    halaqatError,
    issueAchievementStatus,
    issueAchievementError,
    submitReportStatus,
    submitReportError,
    registerStudentStatus,
    registerStudentError,
  ];
}
