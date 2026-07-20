part of 'review_schedule_bloc.dart';

abstract class ReviewScheduleEvent extends Equatable {
  const ReviewScheduleEvent();

  @override
  List<Object?> get props => [];
}

class LoadReviewMonthEvent extends ReviewScheduleEvent {
  const LoadReviewMonthEvent();
}

class ChangeReviewMonthEvent extends ReviewScheduleEvent {
  final int delta;

  const ChangeReviewMonthEvent(this.delta);

  @override
  List<Object?> get props => [delta];
}
