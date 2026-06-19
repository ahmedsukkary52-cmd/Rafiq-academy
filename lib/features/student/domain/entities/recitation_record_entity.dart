import 'package:equatable/equatable.dart';

enum RecitationType { memorization, review }

enum RecitationGrade { excellent, veryGood, good, needsRetry }

extension RecitationGradeLabel on RecitationGrade {
  String get label => switch (this) {
    RecitationGrade.excellent => 'ممتاز',
    RecitationGrade.veryGood => 'جيد جداً',
    RecitationGrade.good => 'جيد',
    RecitationGrade.needsRetry => 'يحتاج إعادة',
  };
}

class RecitationRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final String teacherId;
  final String halaqaId;
  final DateTime date;
  final RecitationType type;
  final String versesRange;
  final RecitationGrade grade;
  final String? notes;

  const RecitationRecordEntity({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.halaqaId,
    required this.date,
    required this.type,
    required this.versesRange,
    required this.grade,
    this.notes,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    teacherId,
    halaqaId,
    date,
    type,
    versesRange,
    grade,
    notes,
  ];
}
