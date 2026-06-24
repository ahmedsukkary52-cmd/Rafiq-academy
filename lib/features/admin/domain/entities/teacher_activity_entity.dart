import 'package:equatable/equatable.dart';

class TeacherActivityEntity extends Equatable {
  final String teacherId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<DateTime> activeDates;

  const TeacherActivityEntity({
    required this.teacherId,
    required this.rangeStart,
    required this.rangeEnd,
    required this.activeDates,
  });

  @override
  List<Object?> get props => [teacherId, rangeStart, rangeEnd, activeDates];
}
