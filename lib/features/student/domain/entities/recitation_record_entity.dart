import 'package:equatable/equatable.dart';

enum RecitationType { memorization, review }

/// تقييم يُستخدم لثلاثة محاور: الحفظ، المراجعة، والسلوك
enum RecitationGrade { excellent, veryGood, good, needsRetry }

extension RecitationGradeLabel on RecitationGrade {
  String get label => switch (this) {
    RecitationGrade.excellent => 'ممتاز',
    RecitationGrade.veryGood => 'جيد جداً',
    RecitationGrade.good => 'جيد',
    RecitationGrade.needsRetry => 'يحتاج تحسين',
  };

  /// لون التقدير في الـ UI - مفيد عشان منكررش نفس الـ switch في كل widget
  bool get isPositive =>
      this == RecitationGrade.excellent || this == RecitationGrade.veryGood;
}

class RecitationRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName; // denormalized لتسريع عرض قوائم المعلم
  final String teacherId;
  final String halaqaId;
  final DateTime date;
  final RecitationType type;
  final String versesRange;

  /// تقييم الحفظ أو المراجعة
  final RecitationGrade grade;

  /// تقييم السلوك - ظهر في التصميم كمحور مستقل بجانب الحفظ والمراجعة
  final RecitationGrade behaviorGrade;

  final String? notes;

  const RecitationRecordEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.halaqaId,
    required this.date,
    required this.type,
    required this.versesRange,
    required this.grade,
    required this.behaviorGrade,
    this.notes,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    teacherId,
    halaqaId,
    date,
    type,
    versesRange,
    grade,
    behaviorGrade,
    notes,
  ];
}
