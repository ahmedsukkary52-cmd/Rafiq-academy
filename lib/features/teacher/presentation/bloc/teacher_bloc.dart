import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/usecases/add_recitation_record_usecase.dart';
import '../../domain/usecases/get_halaqa_recitation_records_usecase.dart';
import '../../domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/usecases/get_teacher_halaqt_usecase.dart';
import '../../domain/usecases/record_attendance_usecase.dart';
import '../../domain/usecases/send_assignment_usecase.dart';
import 'teacher_event.dart';

/// @singleton لنفس سبب باقي الـ Blocs: نافذة المعلم متوقع تتنقل بين
/// (قائمة الحلقات → طلاب الحلقة → دفتر التحضير) من غير ما تعيد التحميل.
@singleton
class TeacherBloc extends Bloc<TeacherEvent, TeacherState> {
  final GetTeacherHalaqatUseCase getTeacherHalaqat;
  final GetHalaqaStudentsUseCase getHalaqaStudents;
  final GetHalaqaRecitationRecordsUseCase getHalaqaRecitationRecords;
  final RecordAttendanceUseCase recordAttendance;
  final AddRecitationRecordUseCase addRecitationRecord;
  final SendAssignmentUseCase sendAssignment;

  TeacherBloc({
    required this.getTeacherHalaqat,
    required this.getHalaqaStudents,
    required this.getHalaqaRecitationRecords,
    required this.recordAttendance,
    required this.addRecitationRecord,
    required this.sendAssignment,
  }) : super(TeacherState.initial()) {
    on<LoadTeacherHalaqatEvent>(_onLoadHalaqat);
    on<SelectHalaqaEvent>(_onSelectHalaqa);
    on<LoadHalaqaStudentsEvent>(_onLoadHalaqaStudents);
    on<LoadHalaqaEvaluationsEvent>(_onLoadEvaluations);
    on<RecordAttendanceEvent>(_onRecordAttendance);
    on<AddRecitationRecordEvent>(_onAddRecitationRecord);
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
  // تسجيل الحضور - بنقرة واحدة مع Optimistic Update
  // ══════════════════════════════════════════════════════════════════════

  /// منطق العملية:
  /// 1. نحدّث الـ UI فوراً (قبل ما ننتظر Firestore) عشان الاستجابة تبقى
  ///    لحظية للمعلم وهو بيسجّل حضور حلقة كاملة بسرعة.
  /// 2. نبعت الكتابة الفعلية لـ Firestore في الخلفية.
  /// 3. لو فشلت الكتابة، نرجّع حالة الطالب لقيمتها القديمة (Rollback)
  ///    ونوضح error بسيط، بدل ما نسيب الـ UI يكذب على المعلم.
  Future<void> _onRecordAttendance(
    RecordAttendanceEvent event,
    Emitter<TeacherState> emit,
  ) async {
    final studentIndex = state.students.indexWhere(
      (s) => s.uid == event.record.studentId,
    );

    // الطالب مش موجود في القائمة الحالية أصلاً - متوقعش، بس بنحمي نفسنا
    if (studentIndex == -1) return;

    final previousStudent = state.students[studentIndex];

    final optimisticStudent = HalaqaStudentSummaryEntity(
      uid: previousStudent.uid,
      name: previousStudent.name,
      profileImageUrl: previousStudent.profileImageUrl,
      todayAttendance: event.record.status,
    );

    final optimisticList = List<HalaqaStudentSummaryEntity>.from(state.students)
      ..[studentIndex] = optimisticStudent;

    emit(state.copyWith(students: optimisticList, attendanceError: null));

    final result = await recordAttendance(event.record);

    result.fold(
      (failure) {
        // Rollback: نرجّع الطالب لحالته القديمة قبل المحاولة
        final rolledBackList = List<HalaqaStudentSummaryEntity>.from(
          state.students,
        )..[studentIndex] = previousStudent;

        emit(
          state.copyWith(
            students: rolledBackList,
            attendanceError: failure.message,
          ),
        );
      },
      (_) {
        // نجحت الكتابة - الـ UI أصلاً محدّث من الخطوة الأولى، مفيش حاجة زيادة
      },
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
