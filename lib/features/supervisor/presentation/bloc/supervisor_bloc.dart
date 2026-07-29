import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/repositories/parent_repository.dart';
import '../../domain/usecases/get_supervised_halaqat_usecase.dart';
import '../../domain/usecases/get_supervisor_day_board_usecase.dart';
import '../../domain/usecases/issue_achievement_usecase.dart';
import '../../domain/usecases/register_new_student_usecase.dart';
import '../../domain/usecases/submit_supervisor_report_usecase.dart';
import 'supervisor_event.dart';
import 'supervisor_state.dart';

@singleton
class SupervisorBloc extends Bloc<SupervisorEvent, SupervisorState> {
  final GetSupervisedHalaqatUseCase getSupervisedHalaqat;
  final GetSupervisorDayBoardUseCase getSupervisorDayBoard;
  final IssueAchievementUseCase issueAchievement;
  final SubmitSupervisorReportUseCase submitSupervisorReport;
  final RegisterNewStudentUseCase registerNewStudent;

  SupervisorBloc({
    required this.getSupervisedHalaqat,
    required this.getSupervisorDayBoard,
    required this.issueAchievement,
    required this.submitSupervisorReport,
    required this.registerNewStudent,
  }) : super(SupervisorState.initial()) {
    on<LoadSupervisedHalaqatEvent>(_onLoadHalaqat);
    on<LoadSupervisorDayBoardEvent>(_onLoadDayBoard);
    on<IssueAchievementEvent>(_onIssueAchievement);
    on<ResetIssueAchievementEvent>(_onResetIssueAchievement);
    on<SubmitSupervisorReportEvent>(_onSubmitReport);
    on<ResetSubmitReportEvent>(_onResetSubmitReport);
    on<RegisterNewStudentEvent>(_onRegisterStudent);
    on<ResetRegisterStudentEvent>(_onResetRegisterStudent);
  }

  Future<void> _onLoadHalaqat(
    LoadSupervisedHalaqatEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(halaqatStatus: SectionStatus.loading, halaqatError: null),
    );

    final result = await getSupervisedHalaqat(
      SupervisorIdParams(event.supervisorId),
    );

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          halaqatStatus: SectionStatus.error,
          halaqatError: failure.message,
        ),
      ),
      (halaqat) async {
        emit(
          state.copyWith(halaqatStatus: SectionStatus.loaded, halaqat: halaqat),
        );
        await _deriveDayBoard(emit);
      },
    );
  }

  Future<void> _onLoadDayBoard(
    LoadSupervisorDayBoardEvent event,
    Emitter<SupervisorState> emit,
  ) => _deriveDayBoard(emit);

  Future<void> _deriveDayBoard(Emitter<SupervisorState> emit) async {
    emit(
      state.copyWith(
        dayBoardStatus: SectionStatus.loading,
        dayBoardError: null,
      ),
    );

    final result = await getSupervisorDayBoard(
      SupervisorDayBoardParams(halaqat: state.halaqat),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          dayBoardStatus: SectionStatus.error,
          dayBoardError: failure.message,
        ),
      ),
      (board) => emit(
        state.copyWith(dayBoardStatus: SectionStatus.loaded, dayBoard: board),
      ),
    );
  }

  Future<void> _onIssueAchievement(
    IssueAchievementEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        issueAchievementStatus: SubmissionStatus.submitting,
        issueAchievementError: null,
      ),
    );

    final result = await issueAchievement(event.data);

    result.fold(
      (failure) => emit(
        state.copyWith(
          issueAchievementStatus: SubmissionStatus.error,
          issueAchievementError: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(issueAchievementStatus: SubmissionStatus.success),
      ),
    );
  }

  void _onResetIssueAchievement(
    ResetIssueAchievementEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        issueAchievementStatus: SubmissionStatus.idle,
        issueAchievementError: null,
      ),
    );
  }

  Future<void> _onSubmitReport(
    SubmitSupervisorReportEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        submitReportStatus: SubmissionStatus.submitting,
        submitReportError: null,
      ),
    );

    final result = await submitSupervisorReport(event.report);

    result.fold(
      (failure) => emit(
        state.copyWith(
          submitReportStatus: SubmissionStatus.error,
          submitReportError: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(submitReportStatus: SubmissionStatus.success)),
    );
  }

  void _onResetSubmitReport(
    ResetSubmitReportEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        submitReportStatus: SubmissionStatus.idle,
        submitReportError: null,
      ),
    );
  }

  Future<void> _onRegisterStudent(
    RegisterNewStudentEvent event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(
      state.copyWith(
        registerStudentStatus: SubmissionStatus.submitting,
        registerStudentError: null,
      ),
    );

    final result = await registerNewStudent(
      RegisterStudentParams(
        halaqaId: event.halaqaId,
        studentId: event.studentId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          registerStudentStatus: SubmissionStatus.error,
          registerStudentError: failure.message,
        ),
      ),
      (_) =>
          emit(state.copyWith(registerStudentStatus: SubmissionStatus.success)),
    );
  }

  void _onResetRegisterStudent(
    ResetRegisterStudentEvent event,
    Emitter<SupervisorState> emit,
  ) {
    emit(
      state.copyWith(
        registerStudentStatus: SubmissionStatus.idle,
        registerStudentError: null,
      ),
    );
  }
}
