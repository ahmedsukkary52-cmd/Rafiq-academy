part of 'review_schedule_bloc.dart';

class ReviewScheduleState extends Equatable {
  final SectionStatus status;
  final int hijriYear;
  final int hijriMonth;
  final ReviewMonthEntity? month;
  final String? errorMessage;

  const ReviewScheduleState({
    required this.status,
    required this.hijriYear,
    required this.hijriMonth,
    this.month,
    this.errorMessage,
  });

  factory ReviewScheduleState.initial() {
    final now = HijriCalendar.now();
    return ReviewScheduleState(
      status: SectionStatus.initial,
      hijriYear: now.hYear,
      hijriMonth: now.hMonth,
    );
  }

  ReviewScheduleState copyWith({
    SectionStatus? status,
    int? hijriYear,
    int? hijriMonth,
    ReviewMonthEntity? month,
    String? errorMessage,
  }) {
    return ReviewScheduleState(
      status: status ?? this.status,
      hijriYear: hijriYear ?? this.hijriYear,
      hijriMonth: hijriMonth ?? this.hijriMonth,
      month: month ?? this.month,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    hijriYear,
    hijriMonth,
    month,
    errorMessage,
  ];
}
