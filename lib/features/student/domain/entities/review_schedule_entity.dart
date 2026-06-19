import 'package:equatable/equatable.dart';

enum ReviewStatus { pending, done }

class ReviewScheduleEntity extends Equatable {
  final String id;
  final String studentId;
  final DateTime date;
  final String surahFrom;
  final int ayahFrom;
  final String surahTo;
  final int ayahTo;
  final ReviewStatus status;

  const ReviewScheduleEntity({
    required this.id,
    required this.studentId,
    required this.date,
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
    required this.status,
  });

  bool get isDone => status == ReviewStatus.done;

  @override
  List<Object?> get props => [
    id,
    studentId,
    date,
    surahFrom,
    ayahFrom,
    surahTo,
    ayahTo,
    status,
  ];
}
