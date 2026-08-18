import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/parent_performance.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';

RecitationRecordEntity _record({
  required RecitationGrade grade,
  String reviewStatus = 'reviewed',
}) {
  return RecitationRecordEntity(
    id: grade.label,
    studentId: 's1',
    studentName: 'طالب',
    teacherId: 't1',
    halaqaId: 'h1',
    date: DateTime(2026, 1, 1),
    type: RecitationType.memorization,
    versesRange: '1-5',
    grade: grade,
    reviewStatus: reviewStatus,
  );
}

void main() {
  group('ParentPerformance', () {
    test('uses Analytics weights 100/80/60/40', () {
      final percent = ParentPerformance.averagePercent([
        _record(grade: RecitationGrade.excellent),
        _record(grade: RecitationGrade.needsRetry),
      ]);
      expect(percent, 70);
    });

    test('skips pending reviews', () {
      final percent = ParentPerformance.averagePercent([
        _record(grade: RecitationGrade.excellent, reviewStatus: 'pending'),
      ]);
      expect(percent, isNull);
    });
  });
}
