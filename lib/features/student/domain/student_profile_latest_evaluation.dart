import 'entities/recitation_record_entity.dart';

/// Latest حفظ / مراجعة / سلوك grades composed from existing recitation records.
///
/// Does not invent a grade: each axis is taken from the newest reviewed record
/// that actually has that field. Pending reviews are skipped.
class StudentProfileLatestEvaluation {
  final RecitationGrade? memorizationGrade;
  final RecitationGrade? reviewGrade;
  final RecitationGrade? behaviorGrade;
  final DateTime date;
  final String? notes;
  final RecitationRecordEntity latestRecord;

  const StudentProfileLatestEvaluation({
    required this.memorizationGrade,
    required this.reviewGrade,
    required this.behaviorGrade,
    required this.date,
    required this.latestRecord,
    this.notes,
  });

  bool get hasAnyGrade =>
      memorizationGrade != null ||
      reviewGrade != null ||
      behaviorGrade != null;
}

StudentProfileLatestEvaluation? pickLatestStudentProfileEvaluation(
  Iterable<RecitationRecordEntity> records,
) {
  final reviewed = records.where((record) => !record.isPendingReview).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (reviewed.isEmpty) return null;

  RecitationGrade? memorization;
  RecitationGrade? review;
  RecitationGrade? behavior;
  for (final record in reviewed) {
    if (memorization == null &&
        record.type == RecitationType.memorization &&
        record.grade != null) {
      memorization = record.grade;
    }
    if (review == null &&
        record.type == RecitationType.review &&
        record.grade != null) {
      review = record.grade;
    }
    if (behavior == null && record.behaviorGrade != null) {
      behavior = record.behaviorGrade;
    }
    if (memorization != null && review != null && behavior != null) break;
  }

  final latest = reviewed.first;
  final notes = latest.notes?.trim();
  return StudentProfileLatestEvaluation(
    memorizationGrade: memorization,
    reviewGrade: review,
    behaviorGrade: behavior,
    date: latest.date,
    notes: notes == null || notes.isEmpty ? null : notes,
    latestRecord: latest,
  );
}
