import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/entities/homework_entity.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../domain/usecases/homework_usecases.dart';

part 'homework_event.dart';

part 'homework_state.dart';

@injectable
class HomeworkBloc extends Bloc<HomeworkEvent, HomeworkState> {
  final WatchLatestHomeworkUseCase watchLatestHomework;
  final ToggleHomeworkTaskUseCase toggleHomeworkTask;
  final CompleteHomeworkUseCase completeHomework;
  final SubmitHomeworkRecitationUseCase submitHomeworkRecitation;

  HomeworkBloc({
    required this.watchLatestHomework,
    required this.toggleHomeworkTask,
    required this.completeHomework,
    required this.submitHomeworkRecitation,
  }) : super(const HomeworkState()) {
    on<LoadHomeworkEvent>(_onLoad, transformer: restartable());
    on<ToggleTaskEvent>(_onToggle);
    on<FinishHomeworkEvent>(_onFinish);
    on<ClearHomeworkMessageEvent>(_onClearMessage);
    on<SubmitRecitationEvent>(_onSubmitRecitation);
  }

  Future<void> _onLoad(
    LoadHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(
      state.copyWith(status: SectionStatus.loading, studentId: event.studentId),
    );
    await emit.forEach(
      watchLatestHomework(StudentUidParams(event.studentId)),
      onData: (either) => either.fold(
        (f) => state.copyWith(
          status: SectionStatus.error,
          errorMessage: f.message,
        ),
        (hw) => state.copyWith(
          status: SectionStatus.loaded,
          homework: hw,
          clearHomework: hw == null,
        ),
      ),
    );
  }

  Future<void> _onToggle(
    ToggleTaskEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    final hw = state.homework;
    if (hw == null || hw.isSubmitted) return;
    final result = await toggleHomeworkTask(
      ToggleHomeworkTaskParams(homeworkId: hw.id, taskId: event.taskId),
    );
    result.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (updated) => emit(state.copyWith(homework: updated)),
    );
  }

  Future<void> _onFinish(
    FinishHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    final hw = state.homework;
    if (hw == null || !hw.allCompleted || hw.isSubmitted) return;
    if (state.submissionStatus == SubmissionStatus.submitting) return;
    emit(state.copyWith(submissionStatus: SubmissionStatus.submitting));
    final result = await completeHomework(hw.id);
    result.fold(
      (f) => emit(
        state.copyWith(
          submissionStatus: SubmissionStatus.error,
          errorMessage: f.message,
        ),
      ),
      (points) => emit(
        state.copyWith(
          submissionStatus: SubmissionStatus.success,
          lastEarnedPoints: points,
          // الـ stream هيحدّث isSubmitted من Firestore؛ نحدّث محلياً فوراً للقفل
          homework: hw.copyWith(isSubmitted: true, completedAt: DateTime.now()),
        ),
      ),
    );
  }

  void _onClearMessage(
    ClearHomeworkMessageEvent event,
    Emitter<HomeworkState> emit,
  ) {
    emit(
      state.copyWith(
        submissionStatus: SubmissionStatus.idle,
        lastEarnedPoints: null,
        clearRecitationError: true,
      ),
    );
  }

  Future<void> _onSubmitRecitation(
    SubmitRecitationEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    if (state.recitationUploadStatus == SubmissionStatus.submitting) return;
    emit(
      state.copyWith(
        recitationUploadStatus: SubmissionStatus.submitting,
        clearRecitationError: true,
      ),
    );
    final result = await submitHomeworkRecitation(event.params);
    result.fold(
      (f) => emit(
        state.copyWith(
          recitationUploadStatus: SubmissionStatus.error,
          recitationError: f.message,
        ),
      ),
      (hw) => emit(
        state.copyWith(
          recitationUploadStatus: SubmissionStatus.success,
          homework: hw,
        ),
      ),
    );
  }
}
