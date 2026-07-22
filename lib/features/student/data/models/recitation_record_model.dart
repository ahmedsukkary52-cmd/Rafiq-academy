import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recitation_record_entity.dart';

class RecitationRecordModel extends RecitationRecordEntity {
  const RecitationRecordModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.teacherId,
    required super.halaqaId,
    required super.date,
    required super.type,
    required super.versesRange,
    super.grade,
    super.behaviorGrade,
    super.notes,
    super.audioUrl,
    super.storagePath,
    super.assignmentId,
    super.taskId,
    super.submittedAt,
    super.reviewStatus,
    super.durationSeconds,
  });

  factory RecitationRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecitationRecordModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      teacherId: data['teacherId'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] == 'memorization'
          ? RecitationType.memorization
          : RecitationType.review,
      versesRange: data['versesRange'] ?? '',
      grade: _gradeFromString(data['grade']),
      behaviorGrade: _gradeFromString(data['behaviorGrade']),
      notes: data['notes'] as String?,
      audioUrl: data['audioUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      assignmentId: data['assignmentId'] as String?,
      taskId: data['taskId'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      // التقييمات القديمة (من المعلم) بدون الحقل = reviewed
      reviewStatus: data['reviewStatus'] as String? ?? 'reviewed',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    'teacherId': teacherId,
    'halaqaId': halaqaId,
    'date': Timestamp.fromDate(date),
    'type': type == RecitationType.memorization ? 'memorization' : 'review',
    'versesRange': versesRange,
    // متكتبش الدرجات إلا لو المعلم قيّم فعلاً
    if (grade != null) 'grade': grade!.label,
    if (behaviorGrade != null) 'behaviorGrade': behaviorGrade!.label,
    if (notes != null) 'notes': notes,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (storagePath != null) 'storagePath': storagePath,
    if (assignmentId != null) 'assignmentId': assignmentId,
    if (taskId != null) 'taskId': taskId,
    if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
    'reviewStatus': reviewStatus,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };

  static RecitationGrade? _gradeFromString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return switch (s) {
      'ممتاز' => RecitationGrade.excellent,
      'جيد جداً' => RecitationGrade.veryGood,
      'جيد' => RecitationGrade.good,
      'يحتاج تحسين' => RecitationGrade.needsRetry,
      _ => null,
    };
  }
}
