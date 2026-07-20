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

  bool get isPositive =>
      this == RecitationGrade.excellent || this == RecitationGrade.veryGood;
}

extension RecitationGradeNullableLabel on RecitationGrade? {
  /// عرض آمن: null = لسه المعلم ما قيّمش
  String get displayLabel => this?.label ?? 'قيد المراجعة';
}

class RecitationRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String halaqaId;
  final DateTime date;
  final RecitationType type;
  final String versesRange;

  /// null حتى يقيّم المعلم فعلياً (مثلاً تسميع الطالب بـ reviewStatus=pending)
  final RecitationGrade? grade;
  final RecitationGrade? behaviorGrade;
  final String? notes;

  /// رفع الطالب للتسميع (اختياري — تقييم المعلم القديم بدونها)
  final String? audioUrl;
  final String? storagePath;
  final String? assignmentId;
  final String? taskId;
  final DateTime? submittedAt;

  /// `pending` | `reviewed` — التقييمات القديمة بدون الحقل تُعامل كـ reviewed
  final String reviewStatus;
  final int? durationSeconds;

  const RecitationRecordEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.halaqaId,
    required this.date,
    required this.type,
    required this.versesRange,
    this.grade,
    this.behaviorGrade,
    this.notes,
    this.audioUrl,
    this.storagePath,
    this.assignmentId,
    this.taskId,
    this.submittedAt,
    this.reviewStatus = 'reviewed',
    this.durationSeconds,
  });

  bool get isPendingReview => reviewStatus == 'pending';

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
    audioUrl,
    storagePath,
    assignmentId,
    taskId,
    submittedAt,
    reviewStatus,
    durationSeconds,
  ];
}
