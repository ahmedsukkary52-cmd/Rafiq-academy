part of 'schedule_bloc.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class LoadWeeklySessionsEvent extends ScheduleEvent {
  const LoadWeeklySessionsEvent();
}
