import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/usecases/add_recitation_record_usecase.dart';
import '../../domain/usecases/get_halaqa_attendance_for_date_usecase.dart';
import '../../domain/usecases/get_halaqa_recitation_records_usecase.dart';
import '../../domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/usecases/get_pending_absence_requests_usecase.dart';
import '../../domain/usecases/get_teacher_halaqt_usecase.dart';
import '../../domain/usecases/get_teacher_home_feed_usecase.dart';
import '../../domain/usecases/get_today_agenda_usecase.dart';
import '../../domain/usecases/review_absence_request_usecase.dart';
import '../../domain/usecases/save_day_attendance_usecase.dart';
import '../../domain/usecases/send_assignment_usecase.dart';
import '../../domain/usecases/update_recitation_review_usecase.dart';
import '../../domain/usecases/upsert_teacher_evaluation_usecase.dart';
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
  final UpsertTeacherEvaluationUseCase upsertTeacherEvaluation;
  final UpdateRecitationReviewUseCase updateRecitationReview;
  final SendAssignmentUseCase sendAssignment;
  final GetTeacherHomeFeedUseCase getTeacherHomeFeed;
  final GetPendingAbsenceRequestsUseCase getPendingAbsenceRequests;
  final ReviewAbsenceRequestUseCase reviewAbsenceRequest;

  TeacherBloc({
    required this.getTeacherHalaqat,
    required this.getHalaqaStudents,
    required this.getHalaqaRecitationRecords,
    required this.getHalaqaAttendanceForDate,
    required this.saveDayAttendance,
    required this.addRecitationRecord,
    required this.upsertTeacherEvaluation,
    required this.updateRecitationReview,
    required this.sendAssignment,
    required this.getTeacherHomeFeed,
    required this.getPendingAbsenceRequests,
    required this.reviewAbsenceRequest,
  }) : super(TeacherState.initial()) {
    on<LoadTeacherHalaqatEvent>(_onLoadHalaqat);
    on<LoadTodayAgendaEvent>(_onLoadTodayAgenda);
    on<SelectHalaqaEvent>(_onSelectHalaqa);
    on<LoadHalaqaStudentsEvent>(_onLoadHalaqaStudents);
    on<LoadHalaqaEvaluationsEvent>(_onLoadEvaluations);
    on<LoadHalaqaAttendanceEvent>(_onLoadDayAttendance);
    on<SaveDayAttendanceEvent>(_onSaveDayAttendance);
    on<ResetAttendanceSubmissionEvent>(_onResetAttendanceSubmission);
    on<AddRecitationRecordEvent>(_onAddRecitationRecord);
    on<UpsertTeacherEvaluationEvent>(_onUpsertTeacherEvaluation);
    on<UpdateRecitationReviewEvent>(_onUpdateRecitationReview);
    on<ResetRecitationSubmissionEvent>(_onResetRecitationSubmission);
    on<SendAssignmentEvent>(_onSendAssignment);
    on<ResetAssignmentSubmissionEvent>(_onResetAssignmentSubmission);
    on<LoadPendingAbsenceRequestsEvent>(_onLoadPendingAbsenceRequests);
    on<ReviewAbsenceRequestEvent>(_onReviewAbsenceRequest);
    on<ResetAbsenceReviewEvent>(_onResetAbsenceReview);
    on<ClearTeacherSessionEvent>(_onClearSession);
  }

  void _onClearSession(
    ClearTeacherSessionEvent event,
    Emitter<TeacherState> emit,
  ) {
    emit(TeacherState.initial());
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

    final failure = result.fold<String?>((f) => f.message, (_) => null);
    if (failure != null) {
      emit(
        state.copyWith(
          halaqatStatus: SectionStatus.error,
          halaqatError: failure,
        ),
      );
      return;
    }

    final halaqat = result.getOrElse((_) => const []);
    emit(state.copyWith(halaqatStatus: SectionStatus.loaded, halaqat: halaqat));

    // W3: derive today's agenda from the just-loaded halaqat (no extra read).
    await _deriveTodayAgenda(emit);
  }

  /// Recomputes today's agenda from the halaqat already in state (retry path).
  Future<void> _onLoadTodayAgenda(
    LoadTodayAgendaEvent event,
    Emitter<TeacherState> emit,
  ) => _deriveTodayAgenda(emit);

  Future<void> _deriveTodayAgenda(Emitter<TeacherState> emit) async {
    emit(
      state.copyWith(
        todayAgendaStatus: SectionStatus.loading,
        todayAgendaError: null,
        recentActivitiesStatus: SectionStatus.loading,
        recentActivitiesError: null,
      ),
    );

    final result = await getTeacherHomeFeed(
      TodayAgendaParams(halaqat: state.halaqat),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          todayAgendaStatus: SectionStatus.error,
          todayAgendaError: failure.message,
          recentActivitiesStatus: SectionStatus.error,
          recentActivitiesError: failure.message,
        ),
      ),
      (feed) => emit(
        state.copyWith(
          todayAgendaStatus: SectionStatus.loaded,
          todayAgenda: feed.agenda,
          recentActivitiesStatus: SectionStatus.loaded,
          recentActivities: feed.recentActivities,
        ),
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
        studentsHalaqaId: event.halaqaId,
      ),
    );

    final result = await getHalaqaStudents(
      HalaqaStudentsParams(event.halaqaId),
    );

    // Ignore stale responses after a newer halaqa was requested.
    if (state.studentsHalaqaId != event.halaqaId) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          studentsStatus: SectionStatus.error,
          studentsError: failure.message,
          studentsHalaqaId: event.halaqaId,
        ),
      ),
      (students) => emit(
        state.copyWith(
          studentsStatus: SectionStatus.loaded,
          students: students,
          studentsHalaqaId: event.halaqaId,
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
    final requestedDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    emit(
      state.copyWith(
        dayAttendanceStatus: SectionStatus.loading,
        dayAttendanceError: null,
        dayAttendanceDate: requestedDay,
      ),
    );

    final result = await getHalaqaAttendanceForDate(
      HalaqaAttendanceDateParams(halaqaId: event.halaqaId, date: requestedDay),
    );

    // Ignore stale responses after a newer day was requested.
    final currentDay = state.dayAttendanceDate;
    if (currentDay == null ||
        currentDay.year != requestedDay.year ||
        currentDay.month != requestedDay.month ||
        currentDay.day != requestedDay.day) {
      return;
    }

    result.fold(
      (failure) => emit(
        state.copyWith(
          dayAttendanceStatus: SectionStatus.error,
          dayAttendanceError: failure.message,
          dayAttendanceDate: requestedDay,
        ),
      ),
      (records) => emit(
        state.copyWith(
          dayAttendanceStatus: SectionStatus.loaded,
          dayAttendance: records,
          dayAttendanceDate: requestedDay,
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
        attendanceEventsUnpublished: false,
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
      (outcome) {
        emit(
          state.copyWith(
            attendanceSubmissionStatus: SubmissionStatus.success,
            attendanceEventsUnpublished: outcome.hasUnpublishedEvents,
          ),
        );
        if (event.records.isNotEmpty) {
          add(
            LoadHalaqaAttendanceEvent(
              halaqaId: event.records.first.halaqaId,
              date: event.records.first.date,
            ),
          );
        }
        // W3: remaining-work agenda must refresh after register write.
        add(const LoadTodayAgendaEvent());
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
        attendanceEventsUnpublished: false,
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
        add(const LoadTodayAgendaEvent());
      },
    );
  }

  Future<void> _onUpsertTeacherEvaluation(
    UpsertTeacherEvaluationEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        recitationSubmissionStatus: SubmissionStatus.submitting,
        recitationSubmissionError: null,
      ),
    );

    final result = await upsertTeacherEvaluation(
      UpsertTeacherEvaluationParams(
        identity: event.identity,
        sessionDate: event.sessionDate,
        teacherId: event.teacherId,
        studentName: event.studentName,
        grade: event.grade,
        behaviorGrade: event.behaviorGrade,
        notes: event.notes,
        existingRecords: state.evaluations,
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
        add(LoadHalaqaEvaluationsEvent(event.identity.halaqaId));
        add(const LoadTodayAgendaEvent());
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
        recitationEventsUnpublished: false,
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
      (outcome) {
        emit(
          state.copyWith(
            recitationSubmissionStatus: SubmissionStatus.success,
            recitationEventsUnpublished: outcome.hasUnpublishedEvents,
          ),
        );
        add(LoadHalaqaEvaluationsEvent(event.halaqaId));
        add(const LoadTodayAgendaEvent());
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
        recitationEventsUnpublished: false,
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
        assignmentEventsUnpublished: false,
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
      (outcome) {
        emit(
          state.copyWith(
            assignmentSubmissionStatus: SubmissionStatus.success,
            assignmentEventsUnpublished: outcome.hasUnpublishedEvents,
          ),
        );
        // W3: remaining-work agenda must refresh after homework write.
        add(const LoadTodayAgendaEvent());
      },
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
        assignmentEventsUnpublished: false,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // طلبات الاستئذان (W7 Slice 2 — classify request, not attendance)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadPendingAbsenceRequests(
    LoadPendingAbsenceRequestsEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        pendingAbsenceRequestsStatus: SectionStatus.loading,
        pendingAbsenceRequestsError: null,
        pendingAbsenceRequestsHalaqaId: event.halaqaId,
        pendingAbsenceRequestsDate: event.date,
      ),
    );

    final result = await getPendingAbsenceRequests(
      PendingAbsenceRequestsParams(
        teacherId: event.teacherId,
        halaqaId: event.halaqaId,
        date: event.date,
      ),
    );

    final sameScope =
        state.pendingAbsenceRequestsHalaqaId == event.halaqaId &&
        state.pendingAbsenceRequestsDate != null &&
        state.pendingAbsenceRequestsDate!.year == event.date.year &&
        state.pendingAbsenceRequestsDate!.month == event.date.month &&
        state.pendingAbsenceRequestsDate!.day == event.date.day;
    if (!sameScope) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          pendingAbsenceRequestsStatus: SectionStatus.error,
          pendingAbsenceRequestsError: failure.message,
        ),
      ),
      (requests) => emit(
        state.copyWith(
          pendingAbsenceRequestsStatus: SectionStatus.loaded,
          pendingAbsenceRequests: requests,
        ),
      ),
    );
  }

  Future<void> _onReviewAbsenceRequest(
    ReviewAbsenceRequestEvent event,
    Emitter<TeacherState> emit,
  ) async {
    emit(
      state.copyWith(
        absenceReviewStatus: SubmissionStatus.submitting,
        absenceReviewError: null,
      ),
    );

    final result = await reviewAbsenceRequest(
      ReviewAbsenceRequestParams(
        requestId: event.requestId,
        halaqaId: event.halaqaId,
        teacherId: event.teacherId,
        decision: event.decision,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          absenceReviewStatus: SubmissionStatus.error,
          absenceReviewError: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(absenceReviewStatus: SubmissionStatus.success));
        final date = state.pendingAbsenceRequestsDate;
        if (date != null) {
          add(
            LoadPendingAbsenceRequestsEvent(
              teacherId: event.teacherId,
              halaqaId: event.halaqaId,
              date: date,
            ),
          );
        }
      },
    );
  }

  void _onResetAbsenceReview(
    ResetAbsenceReviewEvent event,
    Emitter<TeacherState> emit,
  ) {
    emit(
      state.copyWith(
        absenceReviewStatus: SubmissionStatus.idle,
        absenceReviewError: null,
      ),
    );
  }
}
