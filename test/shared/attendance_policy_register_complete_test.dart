import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  group('AttendancePolicy.isRegisterComplete', () {
    test('empty roster is vacuously complete', () {
      expect(
        AttendancePolicy.isRegisterComplete(
          rosterStudentIds: const [],
          markedStudentIds: const [],
        ),
        isTrue,
      );
    });

    test('all roster students marked → complete', () {
      expect(
        AttendancePolicy.isRegisterComplete(
          rosterStudentIds: const ['s1', 's2'],
          markedStudentIds: const ['s2', 's1'],
        ),
        isTrue,
      );
    });

    test('missing roster student → incomplete', () {
      expect(
        AttendancePolicy.isRegisterIncomplete(
          rosterStudentIds: const ['s1', 's2'],
          markedStudentIds: const ['s1'],
        ),
        isTrue,
      );
    });

    test('trims blank roster ids', () {
      expect(
        AttendancePolicy.isRegisterComplete(
          rosterStudentIds: const ['s1', '  ', ''],
          markedStudentIds: const ['s1'],
        ),
        isTrue,
      );
    });

    test('extra marks beyond roster do not break completeness', () {
      expect(
        AttendancePolicy.isRegisterComplete(
          rosterStudentIds: const ['s1'],
          markedStudentIds: const ['s1', 'ghost'],
        ),
        isTrue,
      );
    });
  });

  group('AttendancePolicy.isSameCalendarDay', () {
    test('same local day ignores clock time', () {
      expect(
        AttendancePolicy.isSameCalendarDay(
          DateTime(2024, 6, 3, 0, 0),
          DateTime(2024, 6, 3, 23, 59, 59),
        ),
        isTrue,
      );
    });

    test('different calendar days are not the same', () {
      expect(
        AttendancePolicy.isSameCalendarDay(
          DateTime(2024, 6, 3, 23, 59),
          DateTime(2024, 6, 4, 0, 0),
        ),
        isFalse,
      );
    });
  });
}
