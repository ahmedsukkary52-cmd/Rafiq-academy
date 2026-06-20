import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
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

  // ── تسجيل الحضور (Optimistic، عشان كده مفيهاش loading عام) ────────────
  final String? attendanceError;

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
    this.attendanceError,
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
    Object? attendanceError = _unset,
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
      attendanceError: identical(attendanceError, _unset)
          ? this.attendanceError
          : attendanceError as String?,
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
    attendanceError,
    recitationSubmissionStatus,
    recitationSubmissionError,
    assignmentSubmissionStatus,
    assignmentSubmissionError,
  ];
}
