import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/utils/attendance_absence_transitions.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  final day = DateTime(2024, 6, 3, 15, 30);
  final dayStart = AttendancePolicy.dayStart(day);

  AttendanceMarkInput mark({
    required String id,
    required String status,
    String name = 'طالب',
    String halaqaId = 'h1',
  }) {
    return AttendanceMarkInput(
      studentId: id,
      studentName: name,
      halaqaId: halaqaId,
      date: day,
      status: status,
    );
  }

  group('AttendanceAbsenceTransitions', () {
    test('explicit absent from empty previous → StudentAbsentRecorded', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {},
        currentMarks: [mark(id: 's1', status: 'absent')],
      );

      expect(events, hasLength(1));
      final e = events.single as StudentAbsentRecorded;
      expect(e.studentId, 's1');
      expect(e.date, dayStart);
      expect(
        e.attendanceDocumentId,
        AttendancePolicy.documentId(
          halaqaId: 'h1',
          studentId: 's1',
          date: dayStart,
        ),
      );
      expect(
        e.eventId,
        AcademyEventIds.attendanceAbsence(e.attendanceDocumentId),
      );
    });

    test('present → absent → StudentAbsentRecorded', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'present'},
        currentMarks: [mark(id: 's1', status: 'absent')],
      );
      expect(events.single, isA<StudentAbsentRecorded>());
    });

    test('absent → absent → no event (idempotent)', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'absent'},
        currentMarks: [mark(id: 's1', status: 'absent')],
      );
      expect(events, isEmpty);
    });

    test('absent → present → StudentAbsenceCorrected', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'absent'},
        currentMarks: [mark(id: 's1', status: 'present')],
      );
      expect(events, hasLength(1));
      final e = events.single as StudentAbsenceCorrected;
      expect(e.correctedToStatus, AttendancePolicy.statusPresent);
      expect(
        e.eventId,
        AcademyEventIds.attendanceAbsence(e.attendanceDocumentId),
      );
    });

    test('absent → late → StudentAbsenceCorrected', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'absent'},
        currentMarks: [mark(id: 's1', status: 'late')],
      );
      final e = events.single as StudentAbsenceCorrected;
      expect(e.correctedToStatus, AttendancePolicy.statusLate);
    });

    test('late never creates absence event', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {},
        currentMarks: [mark(id: 's1', status: 'late')],
      );
      expect(events, isEmpty);
    });

    test('unknown / null previous is NOT treated as absent', () {
      // Contrast with AttendancePolicy.isAbsentStatus which would say true.
      expect(AttendancePolicy.isAbsentStatus(null), isTrue);
      expect(AttendancePolicy.isAbsentStatus('weird'), isTrue);
      expect(AttendanceAbsenceTransitions.isExplicitAbsent(null), isFalse);
      expect(AttendanceAbsenceTransitions.isExplicitAbsent('weird'), isFalse);

      final fromNull = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': null},
        currentMarks: [mark(id: 's1', status: 'present')],
      );
      expect(fromNull, isEmpty);

      final fromUnknown = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'weird'},
        currentMarks: [mark(id: 's1', status: 'present')],
      );
      expect(fromUnknown, isEmpty);
    });

    test('unknown current status never emits correction/absence', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {'s1': 'absent'},
        currentMarks: [mark(id: 's1', status: 'weird')],
      );
      expect(events, isEmpty);
    });

    test('blank student id is skipped', () {
      final events = AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: const {},
        currentMarks: [mark(id: '  ', status: 'absent')],
      );
      expect(events, isEmpty);
    });

    test(
      'becameAbsent and corrected share eventId for same attendance doc',
      () {
        final absent = AttendanceAbsenceTransitions.project(
          previousStatusByStudentId: const {},
          currentMarks: [mark(id: 's1', status: 'absent')],
        ).single;
        final corrected = AttendanceAbsenceTransitions.project(
          previousStatusByStudentId: const {'s1': 'absent'},
          currentMarks: [mark(id: 's1', status: 'present')],
        ).single;
        expect(absent.eventId, corrected.eventId);
      },
    );
  });

  group('AcademyEventIds', () {
    test('in-app delivery id is parent-scoped', () {
      expect(
        AcademyEventIds.inAppDeliveryId(
          parentId: 'p1',
          eventId: 'attendance_absence_h1_s1_20240603',
        ),
        'p1_attendance_absence_h1_s1_20240603',
      );
    });
  });
}
