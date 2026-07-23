part of 'schedule_bloc.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class LoadWeeklySessionsEvent extends ScheduleEvent {
  final String halaqaId;

  const LoadWeeklySessionsEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}
