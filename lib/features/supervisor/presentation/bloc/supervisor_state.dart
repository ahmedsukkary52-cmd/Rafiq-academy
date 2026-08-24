import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/read_models/supervisor_day_board.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class SupervisorState extends Equatable {
  final SectionStatus halaqatStatus;
  final List<HalaqaEntity> halaqat;
  final String? halaqatError;

  final SectionStatus dayBoardStatus;
  final SupervisorDayBoard dayBoard;
  final String? dayBoardError;

  final SectionStatus absenceRequestsStatus;
  final List<AbsenceRequestEntity> absenceRequests;
  final String? absenceRequestsError;

  final SubmissionStatus issueAchievementStatus;
  final String? issueAchievementError;

  final SubmissionStatus submitReportStatus;
  final String? submitReportError;

  final SubmissionStatus admitStudentStatus;
  final String? admitStudentError;

  final SubmissionStatus transferStudentStatus;
  final String? transferStudentError;

  const SupervisorState({
    this.halaqatStatus = SectionStatus.initial,
    this.halaqat = const [],
    this.halaqatError,
    this.dayBoardStatus = SectionStatus.initial,
    this.dayBoard = SupervisorDayBoard.empty,
    this.dayBoardError,
    this.absenceRequestsStatus = SectionStatus.initial,
    this.absenceRequests = const [],
    this.absenceRequestsError,
    this.issueAchievementStatus = SubmissionStatus.idle,
    this.issueAchievementError,
    this.submitReportStatus = SubmissionStatus.idle,
    this.submitReportError,
    this.admitStudentStatus = SubmissionStatus.idle,
    this.admitStudentError,
    this.transferStudentStatus = SubmissionStatus.idle,
    this.transferStudentError,
  });

  factory SupervisorState.initial() => const SupervisorState();

  SupervisorState copyWith({
    SectionStatus? halaqatStatus,
    List<HalaqaEntity>? halaqat,
    Object? halaqatError = _unset,
    SectionStatus? dayBoardStatus,
    SupervisorDayBoard? dayBoard,
    Object? dayBoardError = _unset,
    SectionStatus? absenceRequestsStatus,
    List<AbsenceRequestEntity>? absenceRequests,
    Object? absenceRequestsError = _unset,
    SubmissionStatus? issueAchievementStatus,
    Object? issueAchievementError = _unset,
    SubmissionStatus? submitReportStatus,
    Object? submitReportError = _unset,
    SubmissionStatus? admitStudentStatus,
    Object? admitStudentError = _unset,
    SubmissionStatus? transferStudentStatus,
    Object? transferStudentError = _unset,
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
      absenceRequestsStatus:
          absenceRequestsStatus ?? this.absenceRequestsStatus,
      absenceRequests: absenceRequests ?? this.absenceRequests,
      absenceRequestsError: identical(absenceRequestsError, _unset)
          ? this.absenceRequestsError
          : absenceRequestsError as String?,
      issueAchievementStatus:
          issueAchievementStatus ?? this.issueAchievementStatus,
      issueAchievementError: identical(issueAchievementError, _unset)
          ? this.issueAchievementError
          : issueAchievementError as String?,
      submitReportStatus: submitReportStatus ?? this.submitReportStatus,
      submitReportError: identical(submitReportError, _unset)
          ? this.submitReportError
          : submitReportError as String?,
      admitStudentStatus: admitStudentStatus ?? this.admitStudentStatus,
      admitStudentError: identical(admitStudentError, _unset)
          ? this.admitStudentError
          : admitStudentError as String?,
      transferStudentStatus:
          transferStudentStatus ?? this.transferStudentStatus,
      transferStudentError: identical(transferStudentError, _unset)
          ? this.transferStudentError
          : transferStudentError as String?,
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
    absenceRequestsStatus,
    absenceRequests,
    absenceRequestsError,
    issueAchievementStatus,
    issueAchievementError,
    submitReportStatus,
    submitReportError,
    admitStudentStatus,
    admitStudentError,
    transferStudentStatus,
    transferStudentError,
  ];
}
