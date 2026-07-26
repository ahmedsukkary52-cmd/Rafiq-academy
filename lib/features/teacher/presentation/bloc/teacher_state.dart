import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/read_models/teacher_day_agenda.dart';

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

  // ── أجندة اليوم (W3 — مشتقّة وقت القراءة، بدون تخزين) ──────────────────
  final SectionStatus todayAgendaStatus;
  final TeacherDayAgenda todayAgenda;
  final String? todayAgendaError;

  // ── طلاب الحلقة المختارة ──────────────────────────────────────────────
  final SectionStatus studentsStatus;
  final List<HalaqaStudentSummaryEntity> students;
  final String? studentsError;

  /// Halaqa id for the in-flight / loaded students roster (guards stale opens).
  final String? studentsHalaqaId;

  // ── تقييمات الحلقة ────────────────────────────────────────────────────
  final SectionStatus evaluationsStatus;
  final List<RecitationRecordEntity> evaluations;
  final String? evaluationsError;

  // ── حضور يوم معيّن ────────────────────────────────────────────────────
  final SectionStatus dayAttendanceStatus;
  final List<AttendanceRecordEntity> dayAttendance;
  final String? dayAttendanceError;

  /// Calendar day currently requested/loaded (guards stale load responses).
  final DateTime? dayAttendanceDate;

  // ── خطأ حضور قديم (غير مستخدم في مسار الحفظ الحالي) ───────────────────
  final String? attendanceError;

  // ── حفظ حضور اليوم ────────────────────────────────────────────────────
  final SubmissionStatus attendanceSubmissionStatus;
  final String? attendanceSubmissionError;

  /// Register saved, but its academy events could not be published.
  final bool attendanceEventsUnpublished;

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
    this.todayAgendaStatus = SectionStatus.initial,
    this.todayAgenda = TeacherDayAgenda.empty,
    this.todayAgendaError,
    this.studentsStatus = SectionStatus.initial,
    this.students = const [],
    this.studentsError,
    this.studentsHalaqaId,
    this.evaluationsStatus = SectionStatus.initial,
    this.evaluations = const [],
    this.evaluationsError,
    this.dayAttendanceStatus = SectionStatus.initial,
    this.dayAttendance = const [],
    this.dayAttendanceError,
    this.dayAttendanceDate,
    this.attendanceError,
    this.attendanceSubmissionStatus = SubmissionStatus.idle,
    this.attendanceSubmissionError,
    this.attendanceEventsUnpublished = false,
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
    SectionStatus? todayAgendaStatus,
    TeacherDayAgenda? todayAgenda,
    Object? todayAgendaError = _unset,
    SectionStatus? studentsStatus,
    List<HalaqaStudentSummaryEntity>? students,
    Object? studentsError = _unset,
    Object? studentsHalaqaId = _unset,
    SectionStatus? evaluationsStatus,
    List<RecitationRecordEntity>? evaluations,
    Object? evaluationsError = _unset,
    SectionStatus? dayAttendanceStatus,
    List<AttendanceRecordEntity>? dayAttendance,
    Object? dayAttendanceError = _unset,
    Object? dayAttendanceDate = _unset,
    Object? attendanceError = _unset,
    SubmissionStatus? attendanceSubmissionStatus,
    Object? attendanceSubmissionError = _unset,
    bool? attendanceEventsUnpublished,
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
      todayAgendaStatus: todayAgendaStatus ?? this.todayAgendaStatus,
      todayAgenda: todayAgenda ?? this.todayAgenda,
      todayAgendaError: identical(todayAgendaError, _unset)
          ? this.todayAgendaError
          : todayAgendaError as String?,
      studentsStatus: studentsStatus ?? this.studentsStatus,
      students: students ?? this.students,
      studentsError: identical(studentsError, _unset)
          ? this.studentsError
          : studentsError as String?,
      studentsHalaqaId: identical(studentsHalaqaId, _unset)
          ? this.studentsHalaqaId
          : studentsHalaqaId as String?,
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
      dayAttendanceDate: identical(dayAttendanceDate, _unset)
          ? this.dayAttendanceDate
          : dayAttendanceDate as DateTime?,
      attendanceError: identical(attendanceError, _unset)
          ? this.attendanceError
          : attendanceError as String?,
      attendanceSubmissionStatus:
          attendanceSubmissionStatus ?? this.attendanceSubmissionStatus,
      attendanceSubmissionError: identical(attendanceSubmissionError, _unset)
          ? this.attendanceSubmissionError
          : attendanceSubmissionError as String?,
      attendanceEventsUnpublished:
          attendanceEventsUnpublished ?? this.attendanceEventsUnpublished,
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
    todayAgendaStatus,
    todayAgenda,
    todayAgendaError,
    studentsStatus,
    students,
    studentsError,
    studentsHalaqaId,
    evaluationsStatus,
    evaluations,
    evaluationsError,
    dayAttendanceStatus,
    dayAttendance,
    dayAttendanceError,
    dayAttendanceDate,
    attendanceError,
    attendanceSubmissionStatus,
    attendanceSubmissionError,
    attendanceEventsUnpublished,
    recitationSubmissionStatus,
    recitationSubmissionError,
    assignmentSubmissionStatus,
    assignmentSubmissionError,
  ];
}
