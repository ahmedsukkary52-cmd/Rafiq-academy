import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/read_models/supervisor_day_board.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class SupervisorState extends Equatable {
  // ── الحلقات تحت الإشراف ───────────────────────────────────────────────
  final SectionStatus halaqatStatus;
  final List<HalaqaEntity> halaqat;
  final String? halaqatError;

  // ── نظرة يوم الإشراف (W6) ─────────────────────────────────────────────
  final SectionStatus dayBoardStatus;
  final SupervisorDayBoard dayBoard;
  final String? dayBoardError;

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
    this.dayBoardStatus = SectionStatus.initial,
    this.dayBoard = SupervisorDayBoard.empty,
    this.dayBoardError,
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
    SectionStatus? dayBoardStatus,
    SupervisorDayBoard? dayBoard,
    Object? dayBoardError = _unset,
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
      dayBoardStatus: dayBoardStatus ?? this.dayBoardStatus,
      dayBoard: dayBoard ?? this.dayBoard,
      dayBoardError: identical(dayBoardError, _unset)
          ? this.dayBoardError
          : dayBoardError as String?,
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
    dayBoardStatus,
    dayBoard,
    dayBoardError,
    issueAchievementStatus,
    issueAchievementError,
    submitReportStatus,
    submitReportError,
    registerStudentStatus,
    registerStudentError,
  ];
}
