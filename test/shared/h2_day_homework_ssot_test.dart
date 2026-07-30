import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/assignment_policy.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';
import 'package:rafiq_academy/features/student/data/models/assignment_model.dart';

void main() {
  group('AssignmentPolicy (H2 / A-H2)', () {
    test('latest-due rule stays limit-1 on dueDate', () {
      expect(AssignmentPolicy.dueDateField, 'dueDate');
      expect(AssignmentPolicy.studentIdField, 'studentId');
      expect(AssignmentPolicy.halaqaIdField, 'halaqaId');
      expect(AssignmentPolicy.latestLimit, 1);
    });
  });

  group('AttendancePolicy dayStart (H2 / A-H3)', () {
    test('dayStart matches local midnight truncation', () {
      final stamped = DateTime(2026, 7, 30, 15, 45, 12);
      expect(
        AttendancePolicy.dayStart(stamped),
        DateTime(2026, 7, 30),
      );
      expect(
        AttendancePolicy.isSameCalendarDay(
          stamped,
          DateTime(2026, 7, 30, 0, 1),
        ),
        isTrue,
      );
      expect(
        AttendancePolicy.isSameCalendarDay(
          stamped,
          DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });
  });

  group('AssignmentModel.defaultHomeworkFields (H2 / A-H12 seed)', () {
    test('seed shape unchanged for empty-tasks repair', () {
      final seed = AssignmentModel.defaultHomeworkFields(
        newMemorizationRange: 'البقرة 1-5',
        reviewRange: 'آل عمران 1-3',
      );

      expect(seed['title'], 'البقرة 1-5');
      expect(seed['isSubmitted'], isFalse);
      final tasks = seed['tasks'] as List;
      expect(tasks, hasLength(3));
      expect(tasks[0]['kind'], 'reading');
      expect(tasks[1]['kind'], 'listening');
      expect(tasks[2]['kind'], 'recitation');
      expect(seed['attachments'], isEmpty);
    });

    test('empty memorization falls back to الورد اليومي title', () {
      final seed = AssignmentModel.defaultHomeworkFields(
        newMemorizationRange: '',
        reviewRange: '',
      );
      expect(seed['title'], 'الورد اليومي');
    });
  });
}
