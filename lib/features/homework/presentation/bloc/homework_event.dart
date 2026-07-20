part of 'homework_bloc.dart';

abstract class HomeworkEvent extends Equatable {
  const HomeworkEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeworkEvent extends HomeworkEvent {
  final String studentId;

  const LoadHomeworkEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

class ToggleTaskEvent extends HomeworkEvent {
  final String taskId;

  const ToggleTaskEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class FinishHomeworkEvent extends HomeworkEvent {
  const FinishHomeworkEvent();
}

class ClearHomeworkMessageEvent extends HomeworkEvent {
  const ClearHomeworkMessageEvent();
}

class SubmitRecitationEvent extends HomeworkEvent {
  final SubmitRecitationParams params;

  const SubmitRecitationEvent(this.params);

  @override
  List<Object?> get props => [params];
}
