part of 'review_schedule_bloc.dart';

class ReviewScheduleState extends Equatable {
  final SectionStatus status;
  final String? studentId;
  final int hijriYear;
  final int hijriMonth;
  final ReviewMonthEntity? month;
  final String? errorMessage;

  const ReviewScheduleState({
    required this.status,
    required this.hijriYear,
    required this.hijriMonth,
    this.studentId,
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
    String? studentId,
    int? hijriYear,
    int? hijriMonth,
    ReviewMonthEntity? month,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReviewScheduleState(
      status: status ?? this.status,
      studentId: studentId ?? this.studentId,
      hijriYear: hijriYear ?? this.hijriYear,
      hijriMonth: hijriMonth ?? this.hijriMonth,
      month: month ?? this.month,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    studentId,
    hijriYear,
    hijriMonth,
    month,
    errorMessage,
  ];
}
