import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class TeacherState extends Equatable {
  // ── الحلقات ────────────────────────────────────────────────────────────
  final SectionStatus halaqatStatus;
  final List<HalaqaEntity> halaqat;
  final String? halaqatError;
  final String? selectedHalaqaId;

  // ── طلاب الحلقة المختارة ──────────────────────────────────────────────
  final SectionStatus studentsStatus;
  final List<HalaqaStudentSummaryEntity> students;
  final String? studentsError;

  // ── تقييمات الحلقة ────────────────────────────────────────────────────
  final SectionStatus evaluationsStatus;
  final List<RecitationRecordEntity> evaluations;
  final String? evaluationsError;

  // ── حضور يوم معيّن ────────────────────────────────────────────────────
  final SectionStatus dayAttendanceStatus;
  final List<AttendanceRecordEntity> dayAttendance;
  final String? dayAttendanceError;

  // ── تسجيل الحضور (Optimistic، عشان كده مفيهاش loading عام) ────────────
  final String? attendanceError;

  // ── حفظ حضور اليوم ────────────────────────────────────────────────────
  final SubmissionStatus attendanceSubmissionStatus;
  final String? attendanceSubmissionError;

  // ── تسجيل تقييم التسميع ───────────────────────────────────────────────
  final SubmissionStatus recitationSubmissionStatus;
  final String? recitationSubmissionError;

  // ── إرسال تكليف ───────────────────────────────────────────────────────
  final SubmissionStatus assignmentSubmissionStatus;
  final String? assignmentSubmissionError;

  const TeacherState({
    this.halaqatStatus = SectionStatus.initial,
    this.halaqat = const [],
    this.halaqatError,
    this.selectedHalaqaId,
    this.studentsStatus = SectionStatus.initial,
    this.students = const [],
    this.studentsError,
    this.evaluationsStatus = SectionStatus.initial,
    this.evaluations = const [],
    this.evaluationsError,
    this.dayAttendanceStatus = SectionStatus.initial,
    this.dayAttendance = const [],
    this.dayAttendanceError,
    this.attendanceError,
    this.attendanceSubmissionStatus = SubmissionStatus.idle,
    this.attendanceSubmissionError,
    this.recitationSubmissionStatus = SubmissionStatus.idle,
    this.recitationSubmissionError,
    this.assignmentSubmissionStatus = SubmissionStatus.idle,
    this.assignmentSubmissionError,
  });

  factory TeacherState.initial() => const TeacherState();

  TeacherState copyWith({
    SectionStatus? halaqatStatus,
    List<HalaqaEntity>? halaqat,
    Object? halaqatError = _unset,
    Object? selectedHalaqaId = _unset,
    SectionStatus? studentsStatus,
    List<HalaqaStudentSummaryEntity>? students,
    Object? studentsError = _unset,
    SectionStatus? evaluationsStatus,
    List<RecitationRecordEntity>? evaluations,
    Object? evaluationsError = _unset,
    SectionStatus? dayAttendanceStatus,
    List<AttendanceRecordEntity>? dayAttendance,
    Object? dayAttendanceError = _unset,
    Object? attendanceError = _unset,
    SubmissionStatus? attendanceSubmissionStatus,
    Object? attendanceSubmissionError = _unset,
    SubmissionStatus? recitationSubmissionStatus,
    Object? recitationSubmissionError = _unset,
    SubmissionStatus? assignmentSubmissionStatus,
    Object? assignmentSubmissionError = _unset,
  }) {
    return TeacherState(
      halaqatStatus: halaqatStatus ?? this.halaqatStatus,
      halaqat: halaqat ?? this.halaqat,
      halaqatError: identical(halaqatError, _unset)
          ? this.halaqatError
          : halaqatError as String?,
      selectedHalaqaId: identical(selectedHalaqaId, _unset)
          ? this.selectedHalaqaId
          : selectedHalaqaId as String?,
      studentsStatus: studentsStatus ?? this.studentsStatus,
      students: students ?? this.students,
      studentsError: identical(studentsError, _unset)
          ? this.studentsError
          : studentsError as String?,
      evaluationsStatus: evaluationsStatus ?? this.evaluationsStatus,
      evaluations: evaluations ?? this.evaluations,
      evaluationsError: identical(evaluationsError, _unset)
          ? this.evaluationsError
          : evaluationsError as String?,
      dayAttendanceStatus: dayAttendanceStatus ?? this.dayAttendanceStatus,
      dayAttendance: dayAttendance ?? this.dayAttendance,
      dayAttendanceError: identical(dayAttendanceError, _unset)
          ? this.dayAttendanceError
          : dayAttendanceError as String?,
      attendanceError: identical(attendanceError, _unset)
          ? this.attendanceError
          : attendanceError as String?,
      attendanceSubmissionStatus:
          attendanceSubmissionStatus ?? this.attendanceSubmissionStatus,
      attendanceSubmissionError: identical(attendanceSubmissionError, _unset)
          ? this.attendanceSubmissionError
          : attendanceSubmissionError as String?,
      recitationSubmissionStatus:
          recitationSubmissionStatus ?? this.recitationSubmissionStatus,
      recitationSubmissionError: identical(recitationSubmissionError, _unset)
          ? this.recitationSubmissionError
          : recitationSubmissionError as String?,
      assignmentSubmissionStatus:
          assignmentSubmissionStatus ?? this.assignmentSubmissionStatus,
      assignmentSubmissionError: identical(assignmentSubmissionError, _unset)
          ? this.assignmentSubmissionError
          : assignmentSubmissionError as String?,
    );
  }

  @override
  List<Object?> get props => [
    halaqatStatus,
    halaqat,
    halaqatError,
    selectedHalaqaId,
    studentsStatus,
    students,
    studentsError,
    evaluationsStatus,
    evaluations,
    evaluationsError,
    dayAttendanceStatus,
    dayAttendance,
    dayAttendanceError,
    attendanceError,
    attendanceSubmissionStatus,
    attendanceSubmissionError,
    recitationSubmissionStatus,
    recitationSubmissionError,
    assignmentSubmissionStatus,
    assignmentSubmissionError,
  ];
}
