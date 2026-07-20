import 'package:equatable/equatable.dart';

enum ReviewItemStatus { completed, today, upcoming }

class ReviewItemEntity extends Equatable {
  final String id;
  final DateTime gregorianDate;
  final int hijriDay;
  final String hijriMonthName;
  final String rangeLabel;
  final int versesCount;
  final ReviewItemStatus status;

  const ReviewItemEntity({
    required this.id,
    required this.gregorianDate,
    required this.hijriDay,
    required this.hijriMonthName,
    required this.rangeLabel,
    required this.versesCount,
    required this.status,
  });

  @override
  List<Object?> get props => [
    id,
    gregorianDate,
    hijriDay,
    hijriMonthName,
    rangeLabel,
    versesCount,
    status,
  ];
}

class ReviewMonthEntity extends Equatable {
  final int hijriYear;
  final int hijriMonth;
  final String monthTitle;
  final List<int> daysWithReview;
  final List<ReviewItemEntity> weekItems;

  const ReviewMonthEntity({
    required this.hijriYear,
    required this.hijriMonth,
    required this.monthTitle,
    required this.daysWithReview,
    required this.weekItems,
  });

  @override
  List<Object?> get props => [
    hijriYear,
    hijriMonth,
    monthTitle,
    daysWithReview,
    weekItems,
  ];
}
