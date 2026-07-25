import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/usecases/add_recitation_record_usecase.dart';
import '../../domain/usecases/get_halaqa_attendance_for_date_usecase.dart';
import '../../domain/usecases/get_halaqa_recitation_records_usecase.dart';
import '../../domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/usecases/get_teacher_halaqt_usecase.dart';
import '../../domain/usecases/save_day_attendance_usecase.dart';
import '../../domain/usecases/send_assignment_usecase.dart';
import '../../domain/usecases/update_recitation_review_usecase.dart';
import 'teacher_event.dart';

/// @singleton لنفس سبب باقي الـ Blocs: نافذة المعلم متوقع تتنقل بين
/// (قائمة الحلقات → طلاب الحلقة → دفتر التحضير) من غير ما تعيد التحميل.
@singleton
class TeacherBloc extends Bloc<TeacherEvent, TeacherState> {
  final GetTeacherHalaqatUseCase getTeacherHalaqat;
  final GetHalaqaStudentsUseCase getHalaqaStudents;
  final GetHalaqaRecitationRecordsUseCase getHalaqaRecitationRecords;
  final GetHalaqaAttendanceForDateUseCase getHalaqaAttendanceForDate;
  final SaveDayAttendanceUseCase saveDayAttendance;
  final AddRecitationRecordUseCase addRecitationRecord;
  final UpdateRecitationReviewUseCase updateRecitationReview;
  final SendAssignmentUseCase sendAssignment;

  TeacherBloc({
    required this.getTeacherHalaqat,
    required this.getHalaqaStudents,
    required this.getHalaqaRecitationRecords,
    required this.getHalaqaAttendanceForDate,
    required this.saveDayAttendance,
    required this.addRecitationRecord,
    required this.updateRecitationReview,
    required this.sendAssignment,
  }) : super(TeacherState.initial()) {
    on<LoadTeacherHalaqatEvent>(_onLoadHalaqat);
    on<SelectHalaqaEvent>(_onSelectHalaqa);
    on<LoadHalaqaStudentsEvent>(_onLoadHalaqaStudents);
    on<LoadHalaqaEvaluationsEvent>(_onLoadEvaluations);
    on<LoadHalaqaAttendanceEvent>(_onLoadDayAttendance);
    on<SaveDayAttendanceEvent>(_onSaveDayAttendance);
    on<ResetAttendanceSubmissionEvent>(_onResetAttendanceSubmission);
    on<AddRecitationRecordEvent>(_onAddRecitationRecord);
    on<UpdateRecitationReviewEvent>(_onUpdateRecitationReview);
    on<ResetRecitationSubmissionEvent>(_onResetRecitationSubmission);
    on<SendAssignmentEvent>(_onSendAssignment);
    on<ResetAssignmentSubmissionEvent>(_onResetAssignmentSubmission);
  }

  // ══════════════════════════════════════════════════════════════════════
  // الحلقات
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadHalaqat(
    LoadTeacherHalaqatEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(halaqatStatus: SectionStatus.loading, halaqatError: null),
    );

    final result = await getTeacherHalaqat(TeacherIdParams(event.teacherId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          halaqatStatus: SectionStatus.error,
          halaqatError: failure.message,
        ),
      ),
      (halaqat) => emit(
        state.copyWith(halaqatStatus: SectionStatus.loaded, halaqat: halaqat),
      ),
    );
  }

  void _onSelectHalaqa(SelectHalaqaEvent event, Emitter<TeacherState> emit) {
    emit(state.copyWith(selectedHalaqaId: event.halaqaId));
    add(LoadHalaqaStudentsEvent(event.halaqaId));
  }

  // ══════════════════════════════════════════════════════════════════════
  // طلاب الحلقة
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadHalaqaStudents(
    LoadHalaqaStudentsEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        studentsStatus: SectionStatus.loading,
        studentsError: null,
      ),
    );

    final result = await getHalaqaStudents(
      HalaqaStudentsParams(event.halaqaId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          studentsStatus: SectionStatus.error,
          studentsError: failure.message,
        ),
      ),
      (students) => emit(
        state.copyWith(
          studentsStatus: SectionStatus.loaded,
          students: students,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تقييمات الحلقة
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadEvaluations(
    LoadHalaqaEvaluationsEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        evaluationsStatus: SectionStatus.loading,
        evaluationsError: null,
      ),
    );

    final result = await getHalaqaRecitationRecords(
      HalaqaStudentsParams(event.halaqaId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          evaluationsStatus: SectionStatus.error,
          evaluationsError: failure.message,
        ),
      ),
      (evaluations) => emit(
        state.copyWith(
          evaluationsStatus: SectionStatus.loaded,
          evaluations: evaluations,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // حضور يوم معيّن
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadDayAttendance(
    LoadHalaqaAttendanceEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        dayAttendanceStatus: SectionStatus.loading,
        dayAttendanceError: null,
      ),
    );

    final result = await getHalaqaAttendanceForDate(
      HalaqaAttendanceDateParams(halaqaId: event.halaqaId, date: event.date),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          dayAttendanceStatus: SectionStatus.error,
          dayAttendanceError: failure.message,
        ),
      ),
      (records) => emit(
        state.copyWith(
          dayAttendanceStatus: SectionStatus.loaded,
          dayAttendance: records,
        ),
      ),
    );
  }

  Future<void> _onSaveDayAttendance(
    SaveDayAttendanceEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        attendanceSubmissionStatus: SubmissionStatus.submitting,
        attendanceSubmissionError: null,
      ),
    );

    final result = await saveDayAttendance(event.records);

    result.fold(
      (failure) => emit(
        state.copyWith(
          attendanceSubmissionStatus: SubmissionStatus.error,
          attendanceSubmissionError: failure.message,
        ),
      ),
      (_) {
        emit(
          state.copyWith(attendanceSubmissionStatus: SubmissionStatus.success),
        );
        if (event.records.isNotEmpty) {
          add(
            LoadHalaqaAttendanceEvent(
              halaqaId: event.records.first.halaqaId,
              date: event.records.first.date,
            ),
          );
        }
      },
    );
  }

  void _onResetAttendanceSubmission(
    ResetAttendanceSubmissionEvent event,
    Emitter<TeacherState> emit,
  ) {
    emit(
      state.copyWith(
        attendanceSubmissionStatus: SubmissionStatus.idle,
        attendanceSubmissionError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تسجيل تقييم التسميع
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onAddRecitationRecord(
    AddRecitationRecordEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        recitationSubmissionStatus: SubmissionStatus.submitting,
        recitationSubmissionError: null,
      ),
    );

    final result = await addRecitationRecord(event.record);

    result.fold(
      (failure) => emit(
        state.copyWith(
          recitationSubmissionStatus: SubmissionStatus.error,
          recitationSubmissionError: failure.message,
        ),
      ),
      (_) {
        emit(
          state.copyWith(recitationSubmissionStatus: SubmissionStatus.success),
        );
        add(LoadHalaqaEvaluationsEvent(event.record.halaqaId));
      },
    );
  }

  Future<void> _onUpdateRecitationReview(
    UpdateRecitationReviewEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        recitationSubmissionStatus: SubmissionStatus.submitting,
        recitationSubmissionError: null,
      ),
    );

    final result = await updateRecitationReview(
      UpdateRecitationReviewParams(
        recordId: event.recordId,
        halaqaId: event.halaqaId,
        grade: event.grade,
        behaviorGrade: event.behaviorGrade,
        notes: event.notes,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          recitationSubmissionStatus: SubmissionStatus.error,
          recitationSubmissionError: failure.message,
        ),
      ),
      (_) {
        emit(
          state.copyWith(recitationSubmissionStatus: SubmissionStatus.success),
        );
        add(LoadHalaqaEvaluationsEvent(event.halaqaId));
      },
    );
  }

  void _onResetRecitationSubmission(
    ResetRecitationSubmissionEvent event,
    Emitter<TeacherState> emit,
  ) {
    emit(
      state.copyWith(
        recitationSubmissionStatus: SubmissionStatus.idle,
        recitationSubmissionError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // إرسال تكليف
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onSendAssignment(
    SendAssignmentEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        assignmentSubmissionStatus: SubmissionStatus.submitting,
        assignmentSubmissionError: null,
      ),
    );

    final result = await sendAssignment(
      SendAssignmentParams(
        halaqaId: event.halaqaId,
        newMemorizationRange: event.newMemorizationRange,
        reviewRange: event.reviewRange,
        dueDate: event.dueDate,
        teacherId: event.teacherId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          assignmentSubmissionStatus: SubmissionStatus.error,
          assignmentSubmissionError: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(assignmentSubmissionStatus: SubmissionStatus.success),
      ),
    );
  }

  void _onResetAssignmentSubmission(
    ResetAssignmentSubmissionEvent event,
    Emitter<TeacherState> emit,
  ) {
    emit(
      state.copyWith(
        assignmentSubmissionStatus: SubmissionStatus.idle,
        assignmentSubmissionError: null,
      ),
    );
  }
}
