import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/services/halaqa_student_summary_projector.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  final now = DateTime(2026, 8, 4, 12);
  const base = HalaqaStudentSummaryEntity(
    uid: 's1',
    name: 'أحمد',
    level: 3,
  );

  test('repeated absences in 14 days → at risk', () {
    final marks = [
      AttendanceMarkRef(
        id: '1',
        halaqaId: 'h1',
        studentId: 's1',
        date: now.subtract(const Duration(days: 2)),
        status: 'absent',
      ),
      AttendanceMarkRef(
        id: '2',
        halaqaId: 'h1',
        studentId: 's1',
        date: now.subtract(const Duration(days: 5)),
        status: 'absent',
      ),
    ];
    final enriched = HalaqaStudentSummaryProjector.enrich(
      base: base,
      attendanceMarks: marks,
      recitations: [
        RecitationRecordEntity(
          id: 'r1',
          studentId: 's1',
          studentName: 'أحمد',
          teacherId: 't1',
          halaqaId: 'h1',
          date: now.subtract(const Duration(days: 1)),
          type: RecitationType.memorization,
          versesRange: '1-5',
          grade: RecitationGrade.excellent,
        ),
      ],
      now: now,
      overallProgressPercent: 55,
    );
    expect(enriched.isAtRisk, isTrue);
    expect(enriched.lastGradeLabel, 'ممتاز');
    expect(enriched.overallProgressPercent, 55);
  });

  test('no recent evaluation → at risk', () {
    final enriched = HalaqaStudentSummaryProjector.enrich(
      base: base,
      attendanceMarks: const [],
      recitations: const [],
      now: now,
    );
    expect(enriched.isAtRisk, isTrue);
  });

  test('recent evaluation and no repeated absence → not at risk', () {
    final enriched = HalaqaStudentSummaryProjector.enrich(
      base: base,
      attendanceMarks: [
        AttendanceMarkRef(
          id: '1',
          halaqaId: 'h1',
          studentId: 's1',
          date: now.subtract(const Duration(days: 1)),
          status: 'present',
        ),
      ],
      recitations: [
        RecitationRecordEntity(
          id: 'r1',
          studentId: 's1',
          studentName: 'أحمد',
          teacherId: 't1',
          halaqaId: 'h1',
          date: now.subtract(const Duration(days: 3)),
          type: RecitationType.memorization,
          versesRange: '1-5',
          grade: RecitationGrade.good,
        ),
      ],
      now: now,
      overallProgressPercent: 80,
    );
    expect(enriched.isAtRisk, isFalse);
    expect(enriched.lastGradeLabel, 'جيد');
    expect(enriched.attendancePercent, 100);
  });
}
