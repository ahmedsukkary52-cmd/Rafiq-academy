import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/utils/absence_request_ids.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  group('AbsenceRequestIds', () {
    test('matches legacy attendance calendar-day encoding for the same inputs', () {
      final day = DateTime(2024, 6, 3, 15, 30);
      expect(
        AbsenceRequestIds.documentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: day,
        ),
        AttendancePolicy.legacyDocumentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: day,
        ),
      );
      expect(
        AbsenceRequestIds.documentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: day,
        ),
        'h1_s1_20240603',
      );
    });
  });
}
